-- =============================================================================
-- XLSX — read-only view as a csv buffer  (library; no keymaps of its own)
-- =============================================================================
-- Wired from config/autocmds.lua (BufReadCmd/BufWriteCmd *.xlsx). The workbook
-- is converted to CSV, one sheet at a time, into a buffer whose filetype is
-- csv — so everything in lang/csv.lua (aligned view, check, sort, filter,
-- viewer) applies unchanged, plus `lw` to switch sheet.
--
-- Deliberately read-only: a csv buffer can't hold formulas, types, formatting
-- or other sheets, so writing back would be silently lossy. `:w` on the .xlsx
-- refuses; `:w name.csv` exports the current sheet.
--
-- Backends: xlsx2csv (fast) or LibreOffice headless (no install, ~1-2s cold
-- start). Sheet names come from xl/workbook.xml via unzip; both backends take
-- a 1-based sheet index in workbook order.

local M = {}

local function sheet_names(path)
  local r = vim.system({ "unzip", "-p", path, "xl/workbook.xml" }, { text = true }):wait()
  if r.code ~= 0 then return {} end
  local names = {}
  for attrs in r.stdout:gmatch("<sheet%s([^>]*)/?>") do
    local name = attrs:match('name="([^"]*)"')
    if name then
      names[#names + 1] = name:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
        :gsub("&apos;", "'"):gsub("&amp;", "&")
    end
  end
  return names
end

-- Returns csv lines, or nil + error message.
local function convert(path, idx)
  if vim.fn.executable("xlsx2csv") == 1 then
    local r = vim.system({ "xlsx2csv", "-s", tostring(idx), path }, { text = true }):wait(60000)
    if r.code ~= 0 then return nil, vim.trim(r.stderr or "") end
    return vim.split(r.stdout:gsub("\r", ""), "\n", { trimempty = false })
  end

  local lo = vim.fn.executable("libreoffice") == 1 and "libreoffice"
    or vim.fn.executable("soffice") == 1 and "soffice"
  if not lo then
    return nil, "no converter: pipx install xlsx2csv (or install libreoffice)"
  end
  -- Own profile dir: a running GUI LibreOffice would otherwise swallow the
  -- headless request and convert nothing.
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  -- Filter options: comma, double quote, UTF-8, from line 1, ..., sheet idx.
  local filter = "csv:Text - txt - csv (StarCalc):44,34,76,1,,0,false,true,false,false,false," .. idx
  local r = vim.system({
    lo, "-env:UserInstallation=file://" .. tmp .. "/profile", "--headless",
    "--convert-to", filter, "--outdir", tmp .. "/out", path,
  }, { text = true }):wait(60000)
  local out = vim.fn.glob(tmp .. "/out/*.csv", false, true)[1]
  local lines = out and vim.fn.readfile(out)
  vim.fn.delete(tmp, "rf")
  if r.code ~= 0 or not lines then
    return nil, "libreoffice conversion failed: " .. vim.trim((r.stderr or "") .. (r.stdout or ""))
  end
  for i, l in ipairs(lines) do lines[i] = l:gsub("\r$", "") end
  return lines
end

-- Fill `buf` with sheet `idx` of the workbook at `path`.
function M.read(buf, path, idx)
  path = vim.fn.fnamemodify(path, ":p")
  idx = idx or 1
  local names = sheet_names(path)
  local lines, err = convert(path, idx)
  if not lines then
    vim.notify("xlsx: " .. err, vim.log.levels.ERROR)
    lines = {}
  end
  while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end

  vim.bo[buf].readonly = false
  local ul = vim.bo[buf].undolevels
  vim.bo[buf].undolevels = -1 -- the load itself isn't an undoable edit
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].undolevels = ul
  vim.bo[buf].modified = false
  vim.bo[buf].readonly = true

  local first_load = vim.b[buf].xlsx == nil
  vim.b[buf].xlsx = { path = path, sheet = idx, sheets = names }

  if first_load then
    -- b:xlsx is set before FileType so lang/csv.lua's filter registers `lw`.
    vim.bo[buf].filetype = "csv"
    if #names > 1 then
      vim.notify(("xlsx: sheet 1/%d \"%s\" — <leader>lw to switch"):format(#names, names[1]))
    end
  else
    -- Same buffer, new sheet: re-detect the header for the new data.
    local ok, csvview = pcall(require, "csvview")
    if ok and csvview.is_enabled(buf) then require("lang.csv").enable_view(buf) end
  end
end

function M.pick_sheet()
  local buf = vim.api.nvim_get_current_buf()
  local x = vim.b[buf].xlsx
  if not x then return end
  if #x.sheets < 2 then
    vim.notify("xlsx: workbook has one sheet"); return
  end
  local items = {}
  for i, n in ipairs(x.sheets) do items[i] = { idx = i, name = n } end
  vim.ui.select(items, {
    prompt = "Sheet",
    format_item = function(it) return (it.idx == x.sheet and "● " or "  ") .. it.name end,
  }, function(it)
    if it then M.read(buf, x.path, it.idx) end
  end)
end

return M

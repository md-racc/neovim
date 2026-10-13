-- =============================================================================
-- CSV / TSV  (+CSV)
-- =============================================================================
-- csvview.nvim aligns columns with virtual text (the file on disk is never
-- reformatted); regex syntax supplies the per-column rainbow (treesitter is
-- skipped for csv/tsv in config/ui.lua). .xlsx files land here too, converted
-- to a read-only csv buffer by lang/xlsx.lua — `lw` (switch sheet) only
-- registers in those.
--
-- lb checks row shape (field count vs. the header, unterminated quotes) to
-- quickfix; lr/lR open an external viewer (csvlens, else visidata); lx filters
-- rows through a shell command; ls sorts by the column under the cursor.

-- RFC 4180-ish record parser. Returns records { first, last, fields } (1-based
-- buffer lines; a quoted field may span lines) and the line of an unterminated
-- quote, if any. The first `skip` lines (a leading comment block) and blank
-- lines are not records. Lines with no quote char take a plain split fast
-- path, so large unquoted files stay cheap.
local function parse(lines, d, q, skip)
  local recs, i, unterminated = {}, (skip or 0) + 1, nil
  while i <= #lines do
    local line = lines[i]
    if line == "" then
      i = i + 1
    elseif not q or not line:find(q, 1, true) then
      recs[#recs + 1] = { first = i, last = i, fields = vim.split(line, d, { plain = true }) }
      i = i + 1
    else
      local start, fields, acc, inq, p = i, {}, {}, false, 1
      while true do
        if p > #line then
          if not inq then break end
          if i == #lines then unterminated = start; break end
          acc[#acc + 1] = "\n"
          i, p = i + 1, 1
          line = lines[i]
        else
          local c = line:sub(p, p)
          if inq then
            if c == q and line:sub(p + 1, p + 1) == q then
              acc[#acc + 1] = q; p = p + 2
            elseif c == q then
              inq = false; p = p + 1
            else
              acc[#acc + 1] = c; p = p + 1
            end
          elseif c == q and #acc == 0 then
            inq = true; p = p + 1
          elseif line:sub(p, p + #d - 1) == d then
            fields[#fields + 1] = table.concat(acc); acc = {}; p = p + #d
          else
            acc[#acc + 1] = c; p = p + 1
          end
        end
      end
      fields[#fields + 1] = table.concat(acc)
      recs[#recs + 1] = { first = start, last = i, fields = fields }
      i = i + 1
    end
  end
  return recs, unterminated
end

-- Buffer layout, read from its first 200 lines. Shared by the view (handed to
-- csvview as delimiter / comment_lines / header_lnum — its own sniffers miss
-- headers on small files and only know "," for csv) and by lb/ls/lx, so the
-- sticky header you see and the rows treated as header always agree.
--   delim, quote  tsv: strict tab, no quoting (IANA). csv: sniffed from the
--                 first data line, since "csv" in the wild is often ; or |.
--   skip          leading "#" comment lines to leave out of the table.
--   header        header line number, or false. A commented header (the last
--                 comment line, `# name<TAB>zone...`, with the same field count
--                 as the data) wins; else the first record unless it has a
--                 numeric cell.
local function layout(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, 200, false)
  local k = 0
  while lines[k + 1] and lines[k + 1]:match("^#") do k = k + 1 end

  local d, q = "\t", nil
  if vim.bo[buf].filetype ~= "tsv" then
    local first = (lines[k + 1] or ""):gsub('"[^"]*"', "") -- quoted delimiters don't count
    local best_n
    d, q, best_n = ",", '"', 0
    for _, cand in ipairs({ ",", ";", "\t", "|" }) do
      local n = select(2, first:gsub(vim.pesc(cand), ""))
      if n > best_n then d, best_n = cand, n end
    end
  end

  local recs = parse(lines, d, q, k)
  local header = false ---@type integer|false
  if k > 0 and recs[1] then
    local h = parse({ (lines[k]:gsub("^#%s*", "")) }, d, q)[1]
    if h and #h.fields > 1 and #h.fields == #recs[1].fields then header = k end
  end
  if not header and recs[2] then
    header = recs[1].first
    for _, f in ipairs(recs[1].fields) do
      if tonumber(f) then header = false; break end
    end
  end
  return { delim = d, quote = q, skip = header == k and k - 1 or k, header = header }
end

local function buf_records(buf)
  local L = layout(buf)
  local recs, unterminated = parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false), L.delim, L.quote, L.skip)
  return recs, unterminated, L
end

-- Number of leading records that are header.
local function header_count(recs, L)
  local n = 0
  for _, r in ipairs(recs) do
    if L.header and r.first <= L.header then n = n + 1 end
  end
  return n
end

-- -----------------------------------------------------------------------------
-- lb — row shape check -> quickfix
-- -----------------------------------------------------------------------------
local function check()
  local buf = vim.api.nvim_get_current_buf()
  local recs, unterminated = buf_records(buf)
  if #recs == 0 then
    vim.notify("csv: empty", vim.log.levels.INFO); return
  end
  local want, items = #recs[1].fields, {}
  if unterminated then
    items[#items + 1] = { bufnr = buf, lnum = unterminated, type = "E",
      text = "unterminated quote (field runs to end of file)" }
  end
  for n, r in ipairs(recs) do
    if #r.fields ~= want then
      items[#items + 1] = { bufnr = buf, lnum = r.first, type = "E",
        text = ("row %d: %d fields, header has %d"):format(n, #r.fields, want) }
    end
  end
  vim.fn.setqflist({}, " ", { title = "csv check", items = items })
  if #items == 0 then
    vim.cmd("cclose")
    vim.notify(("csv: %d rows × %d cols, consistent"):format(#recs, want))
  else
    vim.cmd("copen")
  end
end

-- -----------------------------------------------------------------------------
-- lr / lR — external viewer
-- -----------------------------------------------------------------------------
-- Prefers the file on disk; a modified buffer (or an .xlsx view, which has no
-- csv on disk) is dumped to a temp file first so the viewer sees what you see.
local function viewer(prompt_args)
  local buf = vim.api.nvim_get_current_buf()
  local tsv = vim.bo[buf].filetype == "tsv"
  local bin = (vim.fn.executable("csvlens") == 1 and "csvlens")
    or (vim.fn.executable("vd") == 1 and "vd")
  if not bin then
    vim.notify("No viewer: sudo pacman -S csvlens (or visidata)", vim.log.levels.WARN); return
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].modified or vim.b[buf].xlsx or path == "" then
    path = vim.fn.tempname() .. (tsv and ".tsv" or ".csv")
    vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), path)
  end

  local argv = { bin }
  if bin == "csvlens" then
    local d = layout(buf).delim
    if tsv then argv[#argv + 1] = "-t"
    elseif d ~= "," then vim.list_extend(argv, { "-d", d }) end
  end

  local function launch(extra)
    if extra and extra ~= "" then vim.list_extend(argv, vim.split(extra, "%s+", { trimempty = true })) end
    argv[#argv + 1] = path
    vim.cmd("tabnew")
    local term = vim.api.nvim_get_current_buf()
    vim.fn.jobstart(argv, {
      term = true,
      -- A viewer has nothing worth keeping on exit: close its tab.
      on_exit = vim.schedule_wrap(function()
        if vim.api.nvim_buf_is_valid(term) then vim.api.nvim_buf_delete(term, { force = true }) end
      end),
    })
    vim.cmd("startinsert")
  end

  if prompt_args then
    vim.ui.input({ prompt = bin .. " args: " }, function(a) if a then launch(a) end end)
  else
    launch()
  end
end

-- -----------------------------------------------------------------------------
-- lx — filter rows through a shell command (undoable)
-- -----------------------------------------------------------------------------
-- Normal: every data row (header kept out, so `sort -t, -k2` just works).
-- Visual: the selected lines.
local function filter()
  local buf = vim.api.nvim_get_current_buf()
  local s, e
  if vim.fn.mode():match("[vV\22]") then
    s, e = vim.fn.line("v"), vim.fn.line(".")
    if s > e then s, e = e, s end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  else
    local recs, _, L = buf_records(buf)
    local h = header_count(recs, L)
    if not recs[h + 1] then return end
    s, e = recs[h + 1].first, vim.api.nvim_buf_line_count(buf)
  end
  vim.ui.input({ prompt = ("Filter %d-%d through: "):format(s, e) }, function(cmd)
    if cmd and cmd ~= "" then vim.cmd(("%d,%d!%s"):format(s, e, cmd)) end
  end)
end

-- -----------------------------------------------------------------------------
-- ls — sort data rows by the column under the cursor
-- -----------------------------------------------------------------------------
-- Numeric when every non-empty cell parses as a number, else case-insensitive
-- text; stable; empties last. Pressing ls again on the same column reverses.
-- Multi-line records move as a unit. One undo step.
local function cursor_column(recs, d, q, lnum, col)
  local buf = vim.api.nvim_get_current_buf()
  for _, r in ipairs(recs) do
    if lnum >= r.first and lnum <= r.last then
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, r.first - 1, lnum, false), "\n")
      text = text:sub(1, #text - #vim.fn.getline(lnum) + col)
      local n, inq, p = 1, false, 1
      while p <= #text do
        local c = text:sub(p, p)
        if q and c == q then inq = not inq; p = p + 1
        elseif not inq and text:sub(p, p + #d - 1) == d then n = n + 1; p = p + #d
        else p = p + 1 end
      end
      return n, r
    end
  end
end

local function sort()
  local buf = vim.api.nvim_get_current_buf()
  local recs, unterminated, L = buf_records(buf)
  if unterminated then
    vim.notify("csv: unterminated quote at line " .. unterminated .. " — fix before sorting (lb)",
      vim.log.levels.WARN); return
  end
  local pos = vim.api.nvim_win_get_cursor(0)
  local col = cursor_column(recs, L.delim, L.quote, pos[1], pos[2])
  if not col then return end
  local h = header_count(recs, L)
  local body = vim.list_slice(recs, h + 1)
  if #body < 2 then return end

  local numeric = true
  for _, r in ipairs(body) do
    local v = vim.trim(r.fields[col] or "")
    if v ~= "" and not tonumber(v) then numeric = false; break end
  end

  local last = vim.b[buf].csv_sort
  local desc = last and last.col == col and not last.desc or false
  vim.b[buf].csv_sort = { col = col, desc = desc }

  for i, r in ipairs(body) do
    local v = vim.trim(r.fields[col] or "")
    r.idx, r.empty = i, v == ""
    r.key = numeric and (tonumber(v) or 0) or v:lower()
  end
  table.sort(body, function(a, b)
    if a.empty ~= b.empty then return b.empty end -- empties last, either direction
    if a.key ~= b.key then
      if desc then return a.key > b.key end
      return a.key < b.key
    end
    return a.idx < b.idx
  end)

  local lines, out = vim.api.nvim_buf_get_lines(buf, 0, -1, false), {}
  for _, r in ipairs(body) do
    for l = r.first, r.last do out[#out + 1] = lines[l] end
  end
  local from, to = recs[h + 1].first, recs[#recs].last
  vim.api.nvim_buf_set_lines(buf, from - 1, to, false, out)

  local name = h > 0 and recs[1].fields[col] or ("column " .. col)
  vim.notify(("Sorted by %s %s%s"):format(name, desc and "↓" or "↑", numeric and " (numeric)" or ""))
end

-- -----------------------------------------------------------------------------
-- View
-- -----------------------------------------------------------------------------
local configured = false
local function setup_view()
  if configured then return end
  configured = true
  require("csvview").setup({
    view = { display_mode = "border" },
    keymaps = {
      textobject_field_inner = { "if", mode = { "o", "x" } },
      textobject_field_outer = { "af", mode = { "o", "x" } },
      jump_next_field_end    = { "<Tab>", mode = { "n", "v" } },
      jump_prev_field_end    = { "<S-Tab>", mode = { "n", "v" } },
    },
  })

  -- Upstream race: the sticky-header float's 'statuscolumn' evaluates the
  -- attached window at the float's v:lnum, but its close is vim.schedule()d.
  -- When :copen (lb) splits the csv window, the float briefly belongs to the
  -- 1-line quickfix window -> "Invalid 'use_statuscol_lnum': out of range"
  -- on every redraw in between. The option calls this function by module path,
  -- so guarding it here covers every overlay.
  local overlay = require("csvview.win_overlay")
  local statuscolumn = overlay.statuscolumn
  overlay.statuscolumn = function(winid)
    if vim.api.nvim_win_is_valid(winid)
        and vim.v.lnum > vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(winid)) then
      return ""
    end
    return statuscolumn(winid)
  end
end

-- (Re)enable the view with a freshly detected header. Also used by
-- lang/xlsx.lua after a sheet switch.
local function enable_view(buf)
  setup_view()
  local csvview = require("csvview")
  if csvview.is_enabled(buf) then csvview.disable(buf) end
  local L = layout(buf)
  csvview.enable(buf, {
    parser = { delimiter = L.delim, comment_lines = L.skip },
    view   = { header_lnum = L.header },
  })
end

local function toggle_view()
  local buf = vim.api.nvim_get_current_buf()
  if require("csvview").is_enabled(buf) then
    require("csvview").disable(buf)
  else
    enable_view(buf)
  end
end

return {
  name = "CSV",
  maps = {
    { "lb", check,                          desc = "Check row shape -> quickfix" },
    { "lr", function() viewer(false) end,   desc = "Open in viewer" },
    { "lR", function() viewer(true) end,    desc = "Open in viewer with args" },
    { "lx", filter,                         desc = "Filter rows through cmd" },
    { "lx", filter,                         desc = "Filter selection through cmd", mode = "x" },
    { "ls", sort,                           desc = "Sort by column (again = reverse)" },
    { "lv", toggle_view,                    desc = "Toggle aligned view" },
    { "lw", function() require("lang.xlsx").pick_sheet() end, desc = "Switch sheet (xlsx)" },
  },
  filter = function(buf, lhs)
    return lhs ~= "lw" or vim.b[buf].xlsx ~= nil
  end,
  attach = function(buf)
    vim.wo.wrap = false
    enable_view(buf)
  end,
  enable_view = enable_view,
}

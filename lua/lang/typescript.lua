-- =============================================================================
-- TypeScript  (+TypeScript)   — typescript + typescriptreact
-- =============================================================================
-- lb tsc --noEmit (the project's own tsc from node_modules) -> quickfix, or
-- `astro check` in an Astro project (plain tsc can't resolve .astro imports),
-- lr / lR run the file with node (Node >= 23.6 strips types natively),
-- lc/lC call hierarchy (ts_ls).

local function root()
  return vim.fs.root(0, { "tsconfig.json", "package.json" }) or vim.fn.expand("%:p:h")
end

-- Parse tsc's --pretty false lines (`file(line,col): error TSxxxx: msg`) and
-- astro check's (`file:line:col - error ts(xxxx): msg`), anchoring relative
-- paths at the project root.
local function to_qf(lines, dir, title)
  local items = {}
  for _, l in ipairs(lines) do
    l = l:gsub("\27%[[%d;]*m", "") -- astro check colours even with NO_COLOR
    local f, ln, col, msg = l:match("^(.-)%((%d+),(%d+)%): (.*)$")
    if not f then f, ln, col, msg = l:match("^(%S-):(%d+):(%d+) %- (.*)$") end
    if f then
      if f:sub(1, 1) ~= "/" then f = vim.fs.normalize(dir .. "/" .. f) end
      items[#items + 1] = {
        filename = f, lnum = tonumber(ln), col = tonumber(col), text = msg,
        type = msg:match("^error") and "E" or "W",
      }
    elseif l:match("^error") then
      items[#items + 1] = { text = l }
    end
  end
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd("copen")
end

local function check()
  vim.cmd("update")
  local dir = root()
  local cd  = "cd " .. vim.fn.shellescape(dir) .. " && "
  local astro = dir .. "/node_modules/.bin/astro"
  if vim.fn.executable(astro) == 1 then
    local lines = vim.fn.systemlist(cd .. vim.fn.shellescape(astro) .. " check 2>&1")
    to_qf(lines, dir, "astro check"); return
  end
  local tsc = dir .. "/node_modules/.bin/tsc"
  if vim.fn.executable(tsc) ~= 1 then
    tsc = vim.fn.exepath("tsc")
    if tsc == "" then
      vim.notify("tsc not found (no node_modules/.bin/tsc, none on PATH)", vim.log.levels.WARN); return
    end
  end
  local lines = vim.fn.systemlist(cd .. vim.fn.shellescape(tsc) .. " --noEmit --pretty false 2>&1")
  to_qf(lines, dir, "tsc")
end

local function run(with_args)
  vim.cmd("update")
  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  local function go(argv)
    vim.cmd("rightbelow 15split | terminal node " .. file .. (argv and argv ~= "" and (" " .. argv) or ""))
  end
  if with_args then
    vim.ui.input({ prompt = "Program args: " }, function(a) if a ~= nil then go(a) end end)
  else
    go(nil)
  end
end

return {
  name = "TypeScript",
  maps = {
    { "lb", check,                      desc = "Typecheck (tsc / astro check) -> quickfix" },
    { "lr", function() run(false) end,  desc = "Run file (node)" },
    { "lR", function() run(true) end,   desc = "Run with args" },
    { "lc", vim.lsp.buf.incoming_calls, desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls, desc = "Call hierarchy: callees" },
  },
}

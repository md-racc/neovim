-- =============================================================================
-- Go  (+Go)
-- =============================================================================
-- lb go vet ./... (type errors + vet findings) -> quickfix, lr / lR go run the
-- current package, lc/lC/lt call/type hierarchy (gopls). Commands run from the
-- go.mod root so ./... means the whole module.

local function root() return vim.fs.root(0, { "go.mod", "go.work" }) end

-- Parse `file:line:col: msg` lines; go prints paths relative to the cwd it ran
-- in, so anchor them at `dir` (quickfix would resolve them against nvim's cwd).
local function to_qf(lines, dir, title)
  local items = {}
  for _, l in ipairs(lines) do
    local f, ln, col, msg = l:gsub("^vet: ", ""):match("^(.-%.go):(%d+):(%d+): (.*)$")
    if f then
      if f:sub(1, 1) ~= "/" then f = vim.fs.normalize(dir .. "/" .. f) end
      items[#items + 1] = { filename = f, lnum = tonumber(ln), col = tonumber(col), text = msg }
    elseif l ~= "" then
      items[#items + 1] = { text = l }
    end
  end
  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd("copen")
end

local function check()
  vim.cmd("update")
  if vim.fn.executable("go") ~= 1 then
    vim.notify("go not found", vim.log.levels.WARN); return
  end
  -- Outside a module (a stray script), vet just this file.
  local mod   = root()
  local dir   = mod or vim.fn.expand("%:p:h")
  local what  = mod and "./..." or vim.fn.shellescape(vim.fn.expand("%:p"))
  local lines = vim.fn.systemlist("cd " .. vim.fn.shellescape(dir) .. " && go vet " .. what .. " 2>&1")
  to_qf(lines, dir, "go vet")
end

local function run(with_args)
  vim.cmd("update")
  -- In a module run the file's package; outside one, `go run file.go`.
  local mod = root()
  local dir = mod or vim.fn.expand("%:p:h")
  local pkg = vim.fn.shellescape(mod and vim.fn.expand("%:p:h") or vim.fn.expand("%:p"))
  local function go(argv)
    vim.cmd("rightbelow 15split | terminal cd " .. vim.fn.shellescape(dir) .. " && go run "
      .. pkg .. (argv and argv ~= "" and (" " .. argv) or ""))
  end
  if with_args then
    vim.ui.input({ prompt = "Program args: " }, function(a) if a ~= nil then go(a) end end)
  else
    go(nil)
  end
end

return {
  name = "Go",
  maps = {
    { "lb", check,                       desc = "go vet -> quickfix" },
    { "lr", function() run(false) end,   desc = "Run package" },
    { "lR", function() run(true) end,    desc = "Run with args" },
    { "lc", vim.lsp.buf.incoming_calls,  desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls,  desc = "Call hierarchy: callees" },
    { "lt", function() vim.lsp.buf.typehierarchy("subtypes") end,
      desc = "Type hierarchy: subtypes" },
    { "lT", function() vim.lsp.buf.typehierarchy("supertypes") end,
      desc = "Type hierarchy: supertypes" },
  },
}

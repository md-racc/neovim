-- =============================================================================
-- Bash / Shell  (+Shell)
-- =============================================================================
-- lb runs shellcheck to the quickfix list; lr runs the script.

local function check()
  vim.cmd("w")
  if vim.fn.executable("shellcheck") ~= 1 then
    vim.notify("shellcheck not found", vim.log.levels.WARN); return
  end
  local file  = vim.fn.shellescape(vim.fn.expand("%:p"))
  local lines = vim.fn.systemlist("shellcheck --format gcc " .. file .. " 2>&1")
  vim.fn.setqflist({}, " ", { title = "shellcheck", lines = lines, efm = "%f:%l:%c: %m" })
  vim.cmd("copen")
end

local function run()
  vim.cmd("w")
  local path = vim.fn.expand("%:p")
  local file = vim.fn.shellescape(path)
  -- Honor the script's own shebang (shellcheck, one key over, already does)
  -- instead of always forcing bash — a #!/bin/sh or #!/usr/bin/env zsh script
  -- can behave differently under bash than what was just linted.
  local shebang = vim.fn.readfile(path, "", 1)[1]
  local interp  = shebang and shebang:match("^#!%s*(.+)$")
  vim.cmd("rightbelow 15split | terminal " .. (interp and (interp .. " " .. file) or ("bash " .. file)))
end

return {
  name = "Shell",
  maps = {
    { "lb", check, desc = "shellcheck -> quickfix" },
    { "lr", run,   desc = "Run script" },
  },
}

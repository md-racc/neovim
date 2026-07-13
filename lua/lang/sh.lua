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
  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  vim.cmd("rightbelow 15split | terminal bash " .. file)
end

return {
  name = "Shell",
  maps = {
    { "lb", check, desc = "shellcheck -> quickfix" },
    { "lr", run,   desc = "Run script" },
  },
}

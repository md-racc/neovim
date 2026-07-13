-- =============================================================================
-- Lua  (+Lua)
-- =============================================================================
-- lr sources the file; lx executes the selection (v) or current line (n).

local function exec(mode)
  local chunk
  if mode == "v" then
    vim.cmd('noautocmd normal! "vy')
    chunk = vim.fn.getreg("v")
  else
    chunk = vim.api.nvim_get_current_line()
  end
  local ok, err = pcall(function() return assert(loadstring(chunk))() end)
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

return {
  name = "Lua",
  maps = {
    { "lr", "<cmd>source %<cr>",        desc = "Source file" },
    { "lx", function() exec("n") end,   desc = "Execute line" },
    { "lx", function() exec("v") end,   desc = "Execute selection", mode = "x" },
  },
}

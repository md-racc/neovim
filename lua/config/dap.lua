local ok_dap,   dap   = pcall(require, "dap")
local ok_dapui, dapui = pcall(require, "dapui")

if ok_dap and ok_dapui then
  dapui.setup()
  dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
  dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
  dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end

  vim.keymap.set("n", "<F5>",       dap.continue,          { desc = "Debug: continue" })
  vim.keymap.set("n", "<F10>",      dap.step_over,         { desc = "Debug: step over" })
  vim.keymap.set("n", "<F11>",      dap.step_into,         { desc = "Debug: step into" })
  vim.keymap.set("n", "<F12>",      dap.step_out,          { desc = "Debug: step out" })
  vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  vim.keymap.set("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Conditional breakpoint" })
  vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Open DAP REPL" })
  vim.keymap.set("n", "<leader>du", dapui.toggle,  { desc = "Toggle DAP UI" })
end

local ok_masondap, mason_dap = pcall(require, "mason-nvim-dap")
if ok_masondap then
  mason_dap.setup({
    ensure_installed       = { "python" },
    automatic_installation = true,
    handlers               = {},
  })
end

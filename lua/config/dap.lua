-- =============================================================================
-- DAP / DAP UI
-- =============================================================================

local ok_dap,   dap   = pcall(require, "dap")
local ok_dapui, dapui = pcall(require, "dapui")

if ok_dap and ok_dapui then
  -- Auto-open/close UI with debug session
  dapui.setup()
  dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
  dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
  dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end

  -- Keymaps. The <F5>/<F10>/<F11>/<F12> reflexes are kept *in addition* to the
  -- discoverable <leader>d* namespace.
  vim.keymap.set("n", "<F5>",  dap.continue,  { desc = "Debug: continue" })
  vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
  vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
  vim.keymap.set("n", "<F12>", dap.step_out,  { desc = "Debug: step out" })

  vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
  vim.keymap.set("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Conditional breakpoint" })
  vim.keymap.set("n", "<leader>dc", dap.continue,  { desc = "Continue" })
  vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step into" })
  vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Step over" })
  vim.keymap.set("n", "<leader>dO", dap.step_out,  { desc = "Step out" })
  vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "DAP REPL" })
  vim.keymap.set("n", "<leader>du", dapui.toggle,  { desc = "Toggle DAP UI" })
  vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Terminate session" })
end

-- =============================================================================
-- ADAPTERS
-- =============================================================================

if ok_dap then
  -- Python (requires: pacman -S python-debugpy)
  dap.adapters.python = {
    type    = "executable",
    command = "python",
    args    = { "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type    = "python",
      request = "launch",
      name    = "Launch file",
      program = "${file}",
    },
  }

  -- C / C++ (requires: pacman -S gdb)
  dap.adapters.gdb = {
    type    = "executable",
    command = "gdb",
    args    = { "--interpreter=dap", "--eval-command", "set print pretty on" },
  }
  dap.configurations.c = {
    {
      name    = "Launch",
      type    = "gdb",
      request = "launch",
      program = function()
        return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
      end,
      cwd     = "${workspaceFolder}",
    },
  }
  dap.configurations.cpp = dap.configurations.c
end

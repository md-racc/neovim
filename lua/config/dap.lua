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

-- =============================================================================
-- EMBEDDED ON-CHIP DEBUG (§6) — no new keys, only extra configurations.
-- =============================================================================
-- The host gdb configuration stays and stays FIRST; a profile-specific entry is
-- appended per buffer (rebuilt on buffer switch) so the picker only offers what
-- fits the project. Everything is guarded: a missing Node (cortex-debug) or esp
-- gdb degrades to "config present but errors at launch", never a broken
-- <leader>d. db/dc/di/do/dO/dr/dt/du keep their meanings against these adapters.

local ok_embed, embedded = pcall(require, "lang.embedded")
if ok_dap and ok_embed then
  -- STM32 debug via cortex-debug (wraps VS Code's adapter; needs Node +
  -- debugadapter.js). pcall so a missing Node just means STM32 debug is
  -- unavailable. Provided by the nvim-dap-cortex-debug spec in init.lua.
  pcall(function() require("dap-cortex-debug").setup({}) end)

  -- ESP32 debug: a gdb DAP adapter that selects the xtensa/riscv esp-gdb at
  -- session start (§6). Requires `lfo` (idf.py openocd) running first.
  dap.adapters["esp-gdb"] = function(callback)
    local p   = embedded.detect(0)
    local gdb = (p and p.arch == "xtensa") and "xtensa-esp-elf-gdb" or "riscv32-esp-elf-gdb"
    if vim.fn.executable(gdb) ~= 1 then gdb = "gdb" end -- fall back to system gdb
    callback({ type = "executable", command = gdb, args = { "--interpreter=dap" } })
  end

  -- Concrete config builders (no function-valued fields — maximal adapter
  -- compatibility; recomputed per buffer below).
  local function stm32_family(root)
    local ioc = vim.fn.glob(root .. "/*.ioc", true, true)[1]
    if ioc then
      local ok, content = pcall(vim.fn.readfile, ioc)
      local fam = ok and table.concat(content, "\n"):match("Mcu%.Family=STM32(%w+)")
      if fam then return "stm32" .. fam:sub(1, 1):lower() .. "x" end
    end
    return "stm32f1x" -- conservative default; user edits configFiles if wrong
  end

  local function stm32_cfg(p)
    return {
      name            = "STM32 (cortex-debug)",
      type            = "cortex-debug",
      request         = "launch",
      servertype      = "openocd",
      cwd             = "${workspaceFolder}",
      executable      = p.elf or (p.build_dir .. "/app.elf"),
      gdbPath         = "arm-none-eabi-gdb",
      toolchainPrefix = "arm-none-eabi",
      configFiles     = { "interface/stlink.cfg", "target/" .. stm32_family(p.root) .. ".cfg" },
      runToEntryPoint = "main",
      svdFile         = vim.fn.glob(p.root .. "/*.svd", true, true)[1],
      -- RTT gives a log channel without burning the UART the monitor uses.
      rttConfig       = { enabled = true, address = "auto",
        decoders = { { type = "console", label = "RTT", port = 0 } } },
    }
  end

  local function esp_cfg(p)
    return {
      name    = "ESP32 (attach, openocd :3333)",
      type    = "esp-gdb",
      request = "attach",
      program = vim.fn.glob(p.build_dir .. "/*.elf", true, true)[1] or (p.build_dir .. "/app.elf"),
      cwd     = "${workspaceFolder}",
      target  = "localhost:3333", -- gdb 14+ DAP remote attach; needs `lfo` first
    }
  end

  -- Rebuild c/cpp configurations for the current buffer: host first, then the
  -- profile entry. PlatformIO is intentionally omitted — `pio debug` generates
  -- its own per-board gdb-server invocation (§7).
  local host_c = vim.deepcopy(dap.configurations.c or {})
  local function refresh()
    local list = vim.deepcopy(host_c)
    local p = embedded.detect(0)
    if p then
      if p.kind == "stm32" then
        list[#list + 1] = stm32_cfg(p)
      elseif p.kind == "esp_idf" then
        list[#list + 1] = esp_cfg(p)
      end
    end
    dap.configurations.c   = list
    dap.configurations.cpp = list
  end

  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    group    = vim.api.nvim_create_augroup("EmbeddedDapConfigs", { clear = true }),
    callback = function()
      local ft = vim.bo.filetype
      if ft == "c" or ft == "cpp" then refresh() end
    end,
  })
  refresh() -- current buffer at load time (dap is lazy-loaded on first <leader>d)
end

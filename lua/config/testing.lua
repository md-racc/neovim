-- =============================================================================
-- TESTING  (+Test, <leader>t) — Neotest
-- =============================================================================
-- Invoked from the neotest plugin config in init.lua, so neotest is loaded here.
-- Adapters: neotest-python (pytest/unittest) and neotest-gtest (GoogleTest /
-- ctest) so the most-developed part of this config — C++ — isn't left half-dead.

local ok_neotest, neotest = pcall(require, "neotest")
if not ok_neotest then return end

local adapters = {}

local ok_py, neotest_python = pcall(require, "neotest-python")
if ok_py then
  -- Honour the interpreter picked via <leader>lv (vim.g.python_interpreter).
  -- Returning nil falls back to neotest-python's own venv discovery.
  table.insert(adapters, neotest_python({
    python = function() return vim.g.python_interpreter end,
  }))
end

-- neotest-gtest is configured via its own setup() which returns the adapter.
local ok_gt, neotest_gtest = pcall(require, "neotest-gtest")
if ok_gt then table.insert(adapters, neotest_gtest.setup({})) end

neotest.setup({ adapters = adapters })

vim.keymap.set("n", "<leader>tt", function() neotest.run.run() end,
  { desc = "Run nearest test" })
vim.keymap.set("n", "<leader>tf", function() neotest.run.run(vim.fn.expand("%")) end,
  { desc = "Run file" })
vim.keymap.set("n", "<leader>ts", function() neotest.summary.toggle() end,
  { desc = "Toggle summary" })
vim.keymap.set("n", "<leader>to", function() neotest.output_panel.toggle() end,
  { desc = "Toggle output" })
vim.keymap.set("n", "<leader>tl", function() neotest.run.run_last() end,
  { desc = "Run last" })
vim.keymap.set("n", "<leader>td", function() neotest.run.run({ strategy = "dap" }) end,
  { desc = "Debug nearest (DAP)" })

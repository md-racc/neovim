-- =============================================================================
-- TESTING
-- =============================================================================

local ok_neotest, neotest = pcall(require, "neotest")
if ok_neotest then
  local ok_py, neotest_python = pcall(require, "neotest-python")
  local adapters = {}
  if ok_py then table.insert(adapters, neotest_python) end

  neotest.setup({ adapters = adapters })

  vim.keymap.set("n", "<leader>nt",
    function() neotest.run.run() end,
    { desc = "Run nearest test" })
  vim.keymap.set("n", "<leader>nf",
    function() neotest.run.run(vim.fn.expand("%")) end,
    { desc = "Run test file" })
  vim.keymap.set("n", "<leader>ns",
    function() neotest.summary.toggle() end,
    { desc = "Toggle test summary" })
  vim.keymap.set("n", "<leader>no",
    function() neotest.output_panel.toggle() end,
    { desc = "Toggle test output" })
end

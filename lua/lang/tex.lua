-- =============================================================================
-- LaTeX
-- =============================================================================
-- headless: vimtex is dropped on this branch (no latexmk/zathura on the hosts),
-- so there are no <leader>l* maps to label and no compile warning. This module
-- only sets the prose-writing buffer options. No `name`, so no empty +LaTeX
-- group appears in the leader menu.

return {
  maps = {},
  attach = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell        = true
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true
  end,
}

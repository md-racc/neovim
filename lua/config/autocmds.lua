-- Markdown: wrap, concealment, and indent settings
vim.api.nvim_create_autocmd("FileType", {
  pattern  = "markdown",
  callback = function()
    vim.opt_local.textwidth    = 0
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true
    vim.opt_local.breakindent  = true
    vim.opt_local.conceallevel = 2
  end,
})

-- TeX: concealment, spell check, and wrap
vim.api.nvim_create_autocmd("FileType", {
  pattern  = "tex",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell        = true
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true
  end,
})

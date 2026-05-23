-- =============================================================================
-- SYNTAX
-- =============================================================================

-- Treesitter
local ok_ts, ts_configs = pcall(require, "nvim-treesitter.configs")
if ok_ts then
  ts_configs.setup({
    ensure_installed = {
      "python", "cpp", "c", "lua", "bash",
      "latex", "markdown", "markdown_inline",
    },
    auto_install = true,
    highlight    = { enable = true },
    indent       = { enable = true },
  })
end

-- =============================================================================
-- INDENTATION
-- =============================================================================

-- Indent blankline
local ok_ibl, ibl = pcall(require, "ibl")
if ok_ibl then
  ibl.setup({ indent = { char = "│" }, scope = { enabled = true } })
end

-- =============================================================================
-- MARKDOWN
-- =============================================================================

-- Render-markdown (in-buffer rendering)
local ok_rmd, render_markdown = pcall(require, "render-markdown")
if ok_rmd then
  render_markdown.setup({})
end

-- =============================================================================
-- FILE TREE
-- =============================================================================

-- Nvim-tree
local ok_tree, nvim_tree = pcall(require, "nvim-tree")
if ok_tree then
  nvim_tree.setup({})
  vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      require("nvim-tree.api").tree.open()
      -- Focus the editing window, not the tree
      if vim.fn.argc() == 0 or vim.fn.isdirectory(vim.fn.argv(0)) == 0 then
        vim.cmd("wincmd p")
      end
    end,
  })
end

-- =============================================================================
-- STATUSLINE
-- =============================================================================

-- Lualine
local ok_ll, lualine = pcall(require, "lualine")
if ok_ll then
  lualine.setup({
    options = {
      globalstatus        = true,
      section_separators   = { left = "|", right = "|" },
      component_separators = { left = "|", right = "|" },
    },
  })
end

-- =============================================================================
-- TABS
-- =============================================================================

-- Bufferline
local ok_bl, bufferline = pcall(require, "bufferline")
if ok_bl then
  bufferline.setup({
    options = {
      offsets = { { filetype = "NvimTree", text = "Files", highlight = "Directory" } },
    },
  })
end

local function smart_bdelete()
  local cur = vim.api.nvim_get_current_buf()
  local listed = vim.tbl_filter(function(b)
    return vim.fn.buflisted(b) == 1
      and b ~= cur
      and not vim.startswith(vim.fn.bufname(b), "NvimTree")
  end, vim.api.nvim_list_bufs())
  if #listed > 0 then
    vim.api.nvim_set_current_buf(listed[1])
  else
    vim.cmd("enew")
  end
  vim.cmd("bdelete! " .. cur)
end

vim.keymap.set("n", "<C-t>", "<cmd>enew<cr>",  { silent = true, desc = "New buffer" })
vim.keymap.set("n", "<C-w>", smart_bdelete,     { silent = true, desc = "Close buffer" })

for i = 1, 9 do
  vim.keymap.set("n", "<M-" .. i .. ">", "<cmd>BufferLineGoToBuffer " .. i .. "<cr>",
    { silent = true, desc = "Go to buffer " .. i })
end

-- =============================================================================
-- WHICH-KEY
-- =============================================================================

local ok_wk, which_key = pcall(require, "which-key")
if ok_wk then
  which_key.setup({ win = { border = "rounded" } })
  which_key.add({
    { "<leader>D", group = "Debug" },
    { "<leader>g", group = "Git" },
    { "<leader>o", group = "Outline" },
    { "<leader>r", group = "Refactor" },
    { "<leader>x", group = "Diagnostics" },
    { "<leader>y", group = "Yank" },
    { "<leader>c", group = "C++ / Actions" },
    { "<leader>m", group = "Cmake" },
  })
end

-- =============================================================================
-- SURROUND
-- =============================================================================

-- Nvim-surround
local ok_surround, surround = pcall(require, "nvim-surround")
if ok_surround then
  surround.setup()
end

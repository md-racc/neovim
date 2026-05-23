-- =============================================================================
-- FORMATTING
-- =============================================================================

-- Conform
local ok_conform, conform = pcall(require, "conform")
if ok_conform then
  conform.setup({
    formatters_by_ft = {
      python          = { "isort", "black" },
      lua             = { "stylua" },
      javascript      = { "prettier" },
      typescript      = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      html            = { "prettier" },
      css             = { "prettier" },
      json            = { "prettier" },
      yaml            = { "prettier" },
      markdown        = { "prettier" },
      sh              = { "shfmt" },
      bash            = { "shfmt" },
      c               = { "clang_format" },
      cpp             = { "clang_format" },
    },
  })
  vim.keymap.set("n", "<leader>F", function()
    conform.format({ lsp_fallback = true })
  end, { desc = "Format buffer" })
end

-- =============================================================================
-- PAIRS
-- =============================================================================

-- Autopairs
local ok_pairs, npairs = pcall(require, "nvim-autopairs")
if ok_pairs and not vim.g._nvim_autopairs_setup then
  vim.g._nvim_autopairs_setup = true
  npairs.setup({ check_ts = true, enable_moveright = true, map_cr = true, map_bs = true })
  local closers = { [")"] = true, ["]"] = true, ["}"] = true, ['"'] = true, ["'"] = true }
  vim.keymap.set("i", "<C-l>", function()
    local line      = vim.api.nvim_get_current_line()
    local col       = vim.api.nvim_win_get_cursor(0)[2]
    local next_char = line:sub(col + 1, col + 1)
    if closers[next_char] then return "<Right>" end
    return "<C-l>"
  end, { expr = true, noremap = true, silent = true })
end

-- =============================================================================
-- FILE
-- =============================================================================

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>",   { silent = true, desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>",   { silent = true, desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>wqa<cr>", { silent = true, desc = "Save all and quit" })

-- Delete without overwriting clipboard
vim.keymap.set("n", "<leader>d",  '"_d',  { desc = "Delete without clipboard" })
vim.keymap.set("v", "<leader>d",  '"_d',  { desc = "Delete without clipboard" })
vim.keymap.set("n", "<leader>dd", '"_dd', { desc = "Delete line without clipboard" })

-- =============================================================================
-- SEARCH
-- =============================================================================

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>",
  { silent = true, desc = "Clear search highlight" })

-- Keep cursor centered when jumping through search results
vim.keymap.set("n", "n", "nzzzv", { silent = true })
vim.keymap.set("n", "N", "Nzzzv", { silent = true })

-- =============================================================================
-- TERMINAL
-- =============================================================================

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>",
  { silent = true, desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>t", "<cmd>rightbelow vsp | terminal<CR>",
  { silent = true, desc = "Open terminal split" })

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn     = "no"
    vim.cmd("startinsert")
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  pattern  = "term://*",
  callback = function() vim.cmd("startinsert") end,
})

-- =============================================================================
-- CLIPBOARD
-- =============================================================================

-- System clipboard (Wayland: requires wl-clipboard)
vim.keymap.set("v",        "<leader>y",  '"+y',  { silent = true, desc = "Yank to clipboard" })
vim.keymap.set("n",        "<leader>yy", '"+yy', { silent = true, desc = "Yank line to clipboard" })
vim.keymap.set({ "n","v" },"<leader>yp", '"+p',  { silent = true, desc = "Paste from clipboard" })
vim.keymap.set({ "n","v" },"<leader>yP", '"+P',  { silent = true, desc = "Paste before from clipboard" })

-- =============================================================================
-- NAVIGATION
-- =============================================================================

vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true, desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true, desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true, desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true, desc = "Window right" })

-- Keep cursor centered when scrolling half-pages
vim.keymap.set("n", "<C-d>", "<C-d>zz", { silent = true })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { silent = true })

-- Drag selected lines up/down and re-indent
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move lines down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move lines up" })

-- =============================================================================
-- GIT
-- =============================================================================

-- Gitsigns
local ok_gs, gs = pcall(require, "gitsigns")
if ok_gs then
  gs.setup({
    on_attach = function(bufnr)
      local o = function(desc) return { buffer = bufnr, desc = desc } end
      vim.keymap.set("n", "]c",          gs.next_hunk,                    o("Next hunk"))
      vim.keymap.set("n", "[c",          gs.prev_hunk,                    o("Prev hunk"))
      vim.keymap.set("n", "<leader>gs",  gs.stage_hunk,                   o("Stage hunk"))
      vim.keymap.set("n", "<leader>gr",  gs.reset_hunk,                   o("Reset hunk"))
      vim.keymap.set("n", "<leader>gp",  gs.preview_hunk,                 o("Preview hunk"))
      vim.keymap.set("n", "<leader>gb",  gs.toggle_current_line_blame,    o("Toggle blame"))
    end,
  })
end

-- Diffview
local ok_dv, _ = pcall(require, "diffview")
if ok_dv then
  vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>",          { desc = "Diff working tree" })
  vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File git history" })
  vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>",   { desc = "Repo git history" })
  vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",         { desc = "Close diffview" })
end

-- =============================================================================
-- DIAGNOSTICS
-- =============================================================================

-- Trouble
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",
  { desc = "Workspace diagnostics" })
vim.keymap.set("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { desc = "Buffer diagnostics" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })

-- Claude Code
local ok_claude, claudecode = pcall(require, "claudecode")
if ok_claude then
  claudecode.setup()
  vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>",     { desc = "Toggle Claude Code" })
  vim.keymap.set("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
end

-- Conform (formatters)
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

-- Autopairs
local ok_pairs, npairs = pcall(require, "nvim-autopairs")
if ok_pairs and not vim.g._nvim_autopairs_setup then
  vim.g._nvim_autopairs_setup = true
  npairs.setup({ check_ts = true, enable_moveright = true, map_cr = true, map_bs = true })
  local closers = { [")"] = true, ["]"] = true, ["}"] = true, ['"'] = true, ["'"] = true }
  vim.keymap.set("i", "<C-l>", function()
    local line     = vim.api.nvim_get_current_line()
    local col      = vim.api.nvim_win_get_cursor(0)[2]
    local next_char = line:sub(col + 1, col + 1)
    if closers[next_char] then return "<Right>" end
    return "<C-l>"
  end, { expr = true, noremap = true, silent = true })
end

-- Clear search highlight
vim.keymap.set("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>",
  { silent = true, desc = "Clear search highlight" })

-- Terminal
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

-- Clipboard (Wayland: requires wl-clipboard)
vim.keymap.set("v",        "<leader>y",  '"+y',  { silent = true, desc = "Yank to system clipboard" })
vim.keymap.set("n",        "<leader>yy", '"+yy', { silent = true, desc = "Yank line to system clipboard" })
vim.keymap.set({ "n","v" },"<leader>p",  '"+p',  { silent = true, desc = "Paste from system clipboard" })
vim.keymap.set({ "n","v" },"<leader>P",  '"+P',  { silent = true, desc = "Paste before from system clipboard" })

-- Delete without overwriting clipboard
vim.keymap.set({ "n","v" }, "<leader>d",  '"_d',  { silent = true, desc = "Delete without clipboard" })
vim.keymap.set("n",         "<leader>dd", '"_dd', { silent = true, desc = "Delete line without clipboard" })

-- Window navigation (C-w disabled to prevent accidental close)
vim.keymap.set("n", "<C-w>", "<Nop>",  { silent = true })
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true, desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true, desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true, desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true, desc = "Window right" })

-- Splits
vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<cr>", { silent = true, desc = "Vertical split" })
vim.keymap.set("n", "<leader>sh", "<cmd>split<cr>",  { silent = true, desc = "Horizontal split" })

-- Resize
vim.keymap.set("n", "<C-Up>",    "<cmd>resize +2<cr>",          { silent = true, desc = "Increase height" })
vim.keymap.set("n", "<C-Down>",  "<cmd>resize -2<cr>",          { silent = true, desc = "Decrease height" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { silent = true, desc = "Increase width" })
vim.keymap.set("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { silent = true, desc = "Decrease width" })

-- Diffview
local ok_dv, _ = pcall(require, "diffview")
if ok_dv then
  vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>",          { desc = "Diff working tree" })
  vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File git history" })
  vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>",   { desc = "Repo git history" })
  vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",         { desc = "Close diffview" })
end

-- Trouble / diagnostics
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",
  { desc = "Workspace diagnostics" })
vim.keymap.set("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { desc = "Buffer diagnostics" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })

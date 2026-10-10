-- =============================================================================
-- +UI / TOGGLES  (<leader>u)
-- =============================================================================
-- The drain: everything idempotent or view-mode-switching lives here so the top
-- level never grows a one-off toggle again. <leader>uo (code outline) is a
-- plugin key defined on aerial in init.lua; <leader>ui (inlay hints) is here.

-- Simple option flips (window-local) -------------------------------------------
vim.keymap.set("n", "<leader>uw", function() vim.wo.wrap = not vim.wo.wrap end,
  { desc = "Toggle wrap" })
vim.keymap.set("n", "<leader>us", function() vim.wo.spell = not vim.wo.spell end,
  { desc = "Toggle spell" })
vim.keymap.set("n", "<leader>un", function() vim.wo.number = not vim.wo.number end,
  { desc = "Toggle line numbers" })
vim.keymap.set("n", "<leader>ul", function() vim.wo.relativenumber = not vim.wo.relativenumber end,
  { desc = "Toggle relative numbers" })
vim.keymap.set("n", "<leader>uc", function()
  vim.wo.conceallevel = vim.wo.conceallevel == 0 and 2 or 0
end, { desc = "Toggle conceallevel" })

-- Inlay hints (whichever LSP supports them, current buffer) --------------------
vim.keymap.set("n", "<leader>ui", function()
  local buf = vim.api.nvim_get_current_buf()
  vim.lsp.inlay_hint.enable(
    not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
end, { desc = "Toggle inlay hints" })

-- Inline git blame virtual text (distinct from the one-shot <leader>gb popup) --
vim.keymap.set("n", "<leader>ub", function()
  local ok, gs = pcall(require, "gitsigns")
  if ok then gs.toggle_current_line_blame() end
end, { desc = "Toggle inline git blame" })

-- Diagnostics on/off, and their virtual text --------------------------------
vim.keymap.set("n", "<leader>ud", function()
  local on = vim.diagnostic.is_enabled()
  vim.diagnostic.enable(not on)
  vim.notify("Diagnostics " .. (on and "off" or "on"))
end, { desc = "Toggle diagnostics" })

-- Cache the config as it stood before the first toggle-off, so toggling back
-- on restores it exactly — vim.diagnostic.config().virtual_text can be a
-- table (e.g. a custom prefix), and `not cur` would otherwise collapse that
-- to a bare `true` the first time it's turned off, permanently losing it.
local virtual_text_saved = nil
vim.keymap.set("n", "<leader>ux", function()
  local cur = vim.diagnostic.config().virtual_text
  if cur then
    virtual_text_saved = cur
    vim.diagnostic.config({ virtual_text = false })
  else
    vim.diagnostic.config({ virtual_text = virtual_text_saved or true })
  end
  vim.notify("Diagnostic virtual text " .. (cur and "off" or "on"))
end, { desc = "Toggle diagnostic virtual text" })

-- Format-on-save (the BufWritePre autocmd in autocmds.lua reads this flag) -----
vim.g.format_on_save = vim.g.format_on_save ~= false -- default on
vim.keymap.set("n", "<leader>uf", function()
  vim.g.format_on_save = not vim.g.format_on_save
  vim.notify("Format-on-save " .. (vim.g.format_on_save and "on" or "off"))
end, { desc = "Toggle format-on-save" })

-- Hidden files in the tree + fzf pickers ---------------------------------------
vim.g.show_hidden = false
vim.keymap.set("n", "<leader>uh", function()
  vim.g.show_hidden = not vim.g.show_hidden
  local ok_tree, api = pcall(require, "nvim-tree.api")
  if ok_tree then api.tree.toggle_hidden_filter() end
  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if ok_fzf then
    -- setup() REPLACES the previous opts table rather than merging into it, so
    -- re-state the "default" profile from editor.lua or it gets dropped here.
    fzf.setup({ "default", files = { fd_opts = vim.g.show_hidden
      and "--color=never --type f --hidden --exclude .git"
      or  "--color=never --type f" } })
  end
  vim.notify("Hidden files " .. (vim.g.show_hidden and "shown" or "hidden"))
end, { desc = "Toggle hidden files" })

-- Auto-resize splits on terminal resize (moved off <leader>R) ------------------
-- vim.g (not a plain upvalue) so it persists across session/workspace restore
-- the same way its sibling toggles (format_on_save, show_hidden) do — sessionoptions
-- already includes "globals" for exactly this (init.lua).
vim.g.auto_resize_splits = vim.g.auto_resize_splits ~= false -- default on
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("AutoResize", { clear = true }),
  callback = function() if vim.g.auto_resize_splits then vim.cmd("wincmd =") end end,
})
vim.keymap.set("n", "<leader>ur", function()
  vim.g.auto_resize_splits = not vim.g.auto_resize_splits
  vim.notify("Auto-resize splits " .. (vim.g.auto_resize_splits and "on" or "off"))
end, { desc = "Toggle auto-resize splits" })

-- Encoding reload picker (moved off <leader>fe) --------------------------------
local encodings = {
  "utf-8", "utf-16", "utf-16le", "utf-16be",
  "utf-32", "utf-32le", "utf-32be",
  "latin1", "iso-8859-2", "iso-8859-15",
  "cp1252", "cp1251", "cp437",
  "shift-jis", "euc-jp", "euc-kr", "gb2312", "big5",
}
vim.keymap.set("n", "<leader>ue", function()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end
  fzf.fzf_exec(encodings, {
    prompt   = "Encoding> ",
    actions  = { ["default"] = function(sel) if sel[1] then vim.cmd("e ++enc=" .. sel[1]) end end },
    winopts  = { title = " Reload with encoding " },
  })
end, { desc = "Reload with encoding" })

-- Byte-view picker (moved off <leader>fv); `u` still undoes a view -------------
local byte_views = {
  { label = "hex          xxd",              cmd = "%!xxd" },
  { label = "hex plain    xxd -p",           cmd = "%!xxd -p" },
  { label = "binary       xxd -b",           cmd = "%!xxd -b" },
  { label = "octal        od -A x -t o1z -v", cmd = "%!od -A x -t o1z -v" },
  { label = "decimal      od -A x -t d1z -v", cmd = "%!od -A x -t d1z -v" },
  { label = "ascii        od -c",            cmd = "%!od -c" },
  { label = "revert       xxd -r",           cmd = "%!xxd -r" },
}
vim.keymap.set("n", "<leader>uv", function()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then return end
  fzf.fzf_exec(vim.tbl_map(function(v) return v.label end, byte_views), {
    prompt  = "View as> ",
    actions = {
      ["default"] = function(sel)
        for _, v in ipairs(byte_views) do
          if v.label == sel[1] then vim.cmd(v.cmd); break end
        end
      end,
    },
    winopts = { title = " Byte view (u to revert) " },
  })
end, { desc = "Byte view" })

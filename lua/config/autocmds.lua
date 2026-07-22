-- =============================================================================
-- STARTUP
-- =============================================================================

-- Snap viewport to left border whenever the cursor is close enough that
-- column 0 would be visible — prevents the window staying scrolled right
-- after navigating back from a long line.
vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("SnapToLeft", { clear = true }),
  callback = function()
    -- Hot path (every cursor move): bail before allocating anything when the
    -- window can't be side-scrolled at all.
    if vim.wo.wrap then return end
    local view = vim.fn.winsaveview()
    if view.leftcol > 0 and vim.fn.virtcol(".") <= vim.api.nvim_win_get_width(0) then
      view.leftcol = 0
      vim.fn.winrestview(view)
    end
  end,
})

-- Flash the yanked region briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- (Auto-resize on VimResized moved to lua/config/toggles.lua under <leader>ur.)

-- When a real file is opened, wipe any leftover empty unnamed buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.fn.buflisted(buf) == 1
        and vim.api.nvim_buf_get_name(buf) == ""
        and not vim.api.nvim_get_option_value("modified", { buf = buf })
        and buf ~= vim.api.nvim_get_current_buf()
      then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end,
})

-- =============================================================================
-- MARKDOWN
-- =============================================================================

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

-- =============================================================================
-- C / C++  (keymaps live in lua/lang/cpp.lua via the language dispatcher)
-- =============================================================================

-- Format on save (clang-format via conform), toggleable through <leader>uf.
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern  = { "*.c", "*.cpp", "*.h", "*.hpp", "*.cc", "*.cxx", "*.hh" },
  callback = function()
    if vim.g.format_on_save == false then return end
    local ok, conform = pcall(require, "conform")
    if ok then conform.format({ lsp_fallback = true }) end
  end,
})

-- =============================================================================
-- TEX
-- =============================================================================

vim.api.nvim_create_autocmd("FileType", {
  pattern  = "tex",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell        = true
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true

    -- Label <leader>l as +LaTeX for this buffer (vimtex owns the actual maps,
    -- localleader == leader here). mini.clue is the live UI; which-key is the
    -- dormant scaffolding kept for a one-line revert.
    vim.b.miniclue_config = {
      clues = { { mode = "n", keys = "<Leader>l", desc = vim.fn.nr2char(0xF0174) .. " +LaTeX" } },
    }
    local ok_wk, which_key = pcall(require, "which-key")
    if ok_wk then
      which_key.add({ { "<leader>l", group = "LaTeX", icon = "" } })
    end

    -- Warn (once per session) instead of running a sudo install from an
    -- autocmd — package management belongs in a shell, not a FileType event.
    if vim.fn.executable("latexmk") == 0 and not vim.g._latexmk_warned then
      vim.g._latexmk_warned = true
      vim.notify(
        "latexmk not found — no compile. Install with:\n"
          .. "sudo pacman -S --needed texlive-bin texlive-basic texlive-latex"
          .. " texlive-latexrecommended texlive-latexextra texlive-science",
        vim.log.levels.WARN)
    end
  end,
})

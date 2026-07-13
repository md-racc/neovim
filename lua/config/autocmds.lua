-- =============================================================================
-- STARTUP
-- =============================================================================

-- Snap viewport to left border whenever the cursor is close enough that
-- column 0 would be visible — prevents the window staying scrolled right
-- after navigating back from a long line.
vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("SnapToLeft", { clear = true }),
  callback = function()
    local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if info.leftcol > 0 and vim.fn.virtcol(".") <= info.width then
      local view = vim.fn.winsaveview()
      view.leftcol = 0
      vim.fn.winrestview(view)
    end
  end,
})

-- Flash the yanked region briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
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

    local ok_wk, which_key = pcall(require, "which-key")
    if ok_wk then
      which_key.add({ { "<leader>l", group = "LaTeX", icon = "" } })
    end

    if vim.fn.executable("latexmk") == 0 then
      vim.ui.select({ "Yes", "No" }, { prompt = "TeXLive not installed. Install for compile?" }, function(c)
        if c == "Yes" then
          vim.cmd("!sudo pacman -S --noconfirm texlive-bin texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra texlive-science")
        end
      end)
    end
  end,
})

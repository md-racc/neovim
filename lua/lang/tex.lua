-- =============================================================================
-- LaTeX  (+LaTeX)
-- =============================================================================
-- VimTeX owns every mapping here (maplocalleader == leader, so its native
-- <localleader>l* maps land in this namespace already). This module only
-- labels them — `labels` patches the desc of maps a plugin created — and sets
-- the prose-writing buffer options.
--
-- vimtex's verbs don't follow the universal contract (ll compile, le errors,
-- lv view); they're vimtex's documented defaults and stay that way.

return {
  name = "LaTeX",
  maps = {},
  -- Leaf set per :h vimtex-default-mappings. A label whose map doesn't exist
  -- is shown as a hint only: lr (SyncTeX reverse search) is triggered from
  -- the PDF viewer, not typed.
  labels = {
    li = "Info",                    lI = "Info (full)",
    lt = "Table of contents",       lT = "Toggle TOC",
    lq = "Log",                     lv = "View PDF",
    ll = "Compile",                 lL = "Compile selection",
    lS = "Compile (single-shot)",
    lk = "Stop compiler",           lK = "Stop all compilers",
    le = "Errors -> quickfix",      lo = "Compiler output",
    lg = "Status",                  lG = "Status (all)",
    lc = "Clean aux files",         lC = "Clean aux + output",
    lm = "List insert-mode maps",
    lx = "Reload",                  lX = "Reload (full state)",
    ls = "Toggle main file",        la = "Context menu",
    lr = "Reverse search (SyncTeX)",
  },
  attach = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell        = true
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true

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
}

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
  group    = vim.api.nvim_create_augroup("YankFlash", { clear = true }),
  callback = function()
    vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- (Auto-resize on VimResized moved to lua/config/toggles.lua under <leader>ur.)

-- When a real file is opened, wipe any leftover empty unnamed buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  group    = vim.api.nvim_create_augroup("WipeStaleEmptyBuffer", { clear = true }),
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

-- Shared by the <C-b>/<C-i> bold/italic maps below. Buffer text edit, not a
-- motion, so it works the same whether the region came from a visual
-- selection or a simulated `viw`.
local function md_wrap_region(srow, scol, erow, ecol, marker)
  local eline = vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or ""
  ecol = math.min(ecol, #eline)
  vim.api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { marker })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { marker })
end

-- Visual mode: wrap the current selection. Escaping first (rather than
-- reading '<//'>) is necessary because those marks aren't updated until
-- visual mode is left; getpos("v")/getpos(".") are live during selection.
local function md_wrap_visual(marker)
  return function()
    local vpos, cpos = vim.fn.getpos("v"), vim.fn.getpos(".")
    local swap = vpos[2] > cpos[2] or (vpos[2] == cpos[2] and vpos[3] > cpos[3])
    local a, b = swap and cpos or vpos, swap and vpos or cpos
    vim.cmd("normal! \27")
    md_wrap_region(a[2] - 1, a[3] - 1, b[2] - 1, b[3], marker)
  end
end

-- Normal mode: wrap the word under the cursor (simulate `viw` to reuse the
-- same region logic via the '<//'> marks it leaves behind).
local function md_wrap_word(marker)
  return function()
    vim.cmd("normal! viw\27")
    local s, e = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    md_wrap_region(s[2] - 1, s[3] - 1, e[2] - 1, e[3], marker)
  end
end

-- Insert mode: no text to wrap, so drop an empty marker pair and land the
-- cursor between them.
local function md_insert_pair(marker)
  return function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { marker .. marker })
    vim.api.nvim_win_set_cursor(0, { row, col + #marker })
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group    = vim.api.nvim_create_augroup("MarkdownSetup", { clear = true }),
  pattern  = "markdown",
  callback = function()
    vim.opt_local.textwidth    = 0
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true
    vim.opt_local.breakindent  = true
    vim.opt_local.conceallevel = 2

    -- Bold/italic. Buffer-local, so <C-i> shadowing the jumplist-forward
    -- default (same keycode as <Tab> outside kitty's keyboard protocol) is
    -- scoped to markdown only.
    vim.keymap.set("n", "<C-b>", md_wrap_word("**"),   { buffer = true, desc = "Bold word" })
    vim.keymap.set("x", "<C-b>", md_wrap_visual("**"), { buffer = true, desc = "Bold selection" })
    vim.keymap.set("i", "<C-b>", md_insert_pair("**"), { buffer = true, desc = "Insert bold markers" })
    vim.keymap.set("n", "<C-i>", md_wrap_word("*"),    { buffer = true, desc = "Italicize word" })
    vim.keymap.set("x", "<C-i>", md_wrap_visual("*"),  { buffer = true, desc = "Italicize selection" })
    vim.keymap.set("i", "<C-i>", md_insert_pair("*"),  { buffer = true, desc = "Insert italic markers" })
  end,
})

-- =============================================================================
-- C / C++  (keymaps live in lua/lang/cpp.lua via the language dispatcher)
-- =============================================================================

-- Format on save (clang-format via conform), toggleable through <leader>uf.
vim.api.nvim_create_autocmd("BufWritePre", {
  group    = vim.api.nvim_create_augroup("CppFormatOnSave", { clear = true }),
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
  group    = vim.api.nvim_create_augroup("TexSetup", { clear = true }),
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
      clues = {
        { mode = "n", keys = "<Leader>l",  desc = vim.fn.nr2char(0xF0174) .. " +LaTeX" },
        -- vimtex doesn't bind lr to an ordinary keymap (SyncTeX reverse
        -- search is invoked from the PDF viewer's callback, not typed by the
        -- user), so there's no real mapping for set_mapping_desc below to
        -- patch — this is the only leaf that needs the `clues` fallback.
        { mode = "n", keys = "<Leader>lr", desc = "Reverse search (SyncTeX)" },
      },
    }

    -- vimtex's other leaves are real buffer-local <Plug> maps with no
    -- `desc`, and mini.clue's clue window prefers an existing mapping's desc
    -- over anything in `clues` — even an empty one — so a plain `clues`
    -- entry per leaf gets silently stomped back to blank. set_mapping_desc
    -- patches the mapping's own desc field instead, which mini.clue then
    -- picks up normally (:h MiniClue.set_mapping_desc). Leaf set per
    -- vimtex's doc (:h vimtex-default-mappings); pcall skips any vimtex
    -- doesn't create.
    local ok_clue, MiniClue = pcall(require, "mini.clue")
    if ok_clue then
      local leaf_desc = {
        i = "Info",                    I = "Info (full)",
        t = "Table of contents",       T = "Toggle TOC",
        q = "Log",                     v = "View PDF",
        l = "Compile",                 L = "Compile selection",
        S = "Compile (single-shot)",
        k = "Stop compiler",           K = "Stop all compilers",
        e = "Errors -> quickfix",      o = "Compiler output",
        g = "Status",                  G = "Status (all)",
        c = "Clean aux files",         C = "Clean aux + output",
        m = "List insert-mode maps",
        x = "Reload",                  X = "Reload (full state)",
        s = "Toggle main file",        a = "Context menu",
      }
      for key, desc in pairs(leaf_desc) do
        pcall(MiniClue.set_mapping_desc, "n", "<Leader>l" .. key, desc)
      end
    end
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

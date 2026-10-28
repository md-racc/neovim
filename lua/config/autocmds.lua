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

-- Clear the command echo after every Ex command so it doesn't linger.
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group    = vim.api.nvim_create_augroup("ClearCmdEcho", { clear = true }),
  callback = function()
    vim.schedule(function() vim.api.nvim_echo({}, false, {}) end)
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

-- MDX has no built-in detection (a leading `# heading` makes it fall back to
-- `conf`). Give it its own filetype but parse it as markdown: frontmatter,
-- headings and prose highlight; JSX component lines read as html blocks.
vim.filetype.add({ extension = { mdx = "mdx" } })
vim.treesitter.language.register("markdown", "mdx")

-- Soft wrap at word boundaries with indented continuation lines. Window-local,
-- so it's re-applied on BufWinEnter too: FileType fires once per buffer, and a
-- window that last showed a nowrap buffer must not leak that into this one.
local function md_soft_wrap()
  vim.opt_local.wrap        = true
  vim.opt_local.linebreak   = true
  vim.opt_local.breakindent = true
end

local md_group = vim.api.nvim_create_augroup("MarkdownSetup", { clear = true })

vim.api.nvim_create_autocmd("BufWinEnter", {
  group    = md_group,
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if ft == "markdown" or ft == "mdx" then md_soft_wrap() end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group    = md_group,
  pattern  = { "markdown", "mdx" },
  callback = function()
    vim.opt_local.textwidth    = 0
    vim.opt_local.conceallevel = 2
    md_soft_wrap()

    -- Move by screen line through wrapped paragraphs. A count (5j) still
    -- moves logical lines, so relative jumps keep matching the line numbers.
    for _, k in ipairs({ "j", "k" }) do
      vim.keymap.set({ "n", "x" }, k, function()
        return vim.v.count == 0 and "g" .. k or k
      end, { buffer = true, expr = true, desc = k == "j" and "Down (screen line)" or "Up (screen line)" })
    end

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
-- XLSX
-- =============================================================================
-- Opened as a read-only csv buffer (lua/lang/xlsx.lua); tex moved to
-- lua/lang/tex.lua. Neovim's zipPlugin also claims *.xlsx (it's a zip); it is
-- sourced during lazy.setup(), before this file, with one autocmd per
-- extension — drop just its xlsx one so only ours fires.

pcall(vim.api.nvim_clear_autocmds, { group = "zip", event = "BufReadCmd", pattern = "*.xlsx" })
local xlsx_group = vim.api.nvim_create_augroup("XlsxView", { clear = true })
vim.api.nvim_create_autocmd("BufReadCmd", {
  group    = xlsx_group,
  pattern  = "*.xlsx",
  callback = function(args) require("lang.xlsx").read(args.buf, args.match, 1) end,
})
vim.api.nvim_create_autocmd("BufWriteCmd", {
  group    = xlsx_group,
  pattern  = "*.xlsx",
  callback = function()
    vim.notify("xlsx is read-only here — :w name.csv to export this sheet", vim.log.levels.WARN)
  end,
})

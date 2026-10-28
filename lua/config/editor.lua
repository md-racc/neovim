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
      mdx             = { "prettier" }, -- --stdin-filepath picks prettier's mdx parser
      sh              = { "shfmt" },
      bash            = { "shfmt" },
      c               = { "clang_format" },
      cpp             = { "clang_format" },
    },
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      if vim.g.format_on_save ~= false and (ft == "markdown" or ft == "mdx") then
        return { lsp_fallback = true }
      end
    end,
  })
  vim.keymap.set("n", "<leader>cf", function()
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
  -- map_cr = false: let nvim-cmp own <CR> so it can confirm completions.
  -- (autopairs' own <CR> handler checks the native pum, which cmp doesn't use,
  -- so it would otherwise swallow the Enter that should accept a completion.)
  npairs.setup({ check_ts = true, enable_moveright = true, map_cr = false, map_bs = true })
  local closers = { [")"] = true, ["]"] = true, ["}"] = true, ['"'] = true, ["'"] = true }
  vim.keymap.set("i", "<C-l>", function()
    local line      = vim.api.nvim_get_current_line()
    local col       = vim.api.nvim_win_get_cursor(0)[2]
    local next_char = line:sub(col + 1, col + 1)
    if closers[next_char] then return "<Right>" end
    return "<C-l>"
  end, { expr = true, noremap = true, silent = true, desc = "Skip over closer / redraw" })
end

-- =============================================================================
-- FILE
-- =============================================================================

-- Hot tier: quit / save-all-and-quit.
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>",   { silent = true, desc = "Quit" })
vim.keymap.set("n", "<leader>Q", "<cmd>wqa<cr>", { silent = true, desc = "Save all and quit" })

-- Save moved off <leader>w (freed for +Window) onto <C-s>. Insert/visual return
-- to normal after writing.
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>",           { silent = true, desc = "Save" })
vim.keymap.set("i", "<C-s>", "<Esc><cmd>w<cr>",      { silent = true, desc = "Save" })
vim.keymap.set("v", "<C-s>", "<Esc><cmd>w<cr>",      { silent = true, desc = "Save" })

-- =============================================================================
-- FZF
-- =============================================================================

local ok_fzf, fzf = pcall(require, "fzf-lua")
if ok_fzf then
  fzf.setup({ "default" })

  -- Resume the last picker (hot tier).
  vim.keymap.set("n", "<leader><leader>", fzf.resume, { desc = "Resume last picker" })

  -- +Find: only what no other domain owns (symbols -> +Code, diagnostics ->
  -- +Diagnostics, git commits/branches -> +Git).
  vim.keymap.set("n", "<leader>ff", fzf.files,   { desc = "Files (cwd)" })
  vim.keymap.set("n", "<leader>fF", function()
    fzf.files({ fd_opts = "--color=never --type f --hidden --no-ignore --exclude .git" })
  end, { desc = "Files (incl. hidden + ignored)" })
  vim.keymap.set("n", "<leader>fg", fzf.live_grep,  { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { desc = "Grep word under cursor" })
  vim.keymap.set("x", "<leader>fw", fzf.grep_visual, { desc = "Grep selection" })
  vim.keymap.set("n", "<leader>fb", fzf.buffers,    { desc = "Buffers" })
  vim.keymap.set("n", "<leader>fr", fzf.oldfiles,   { desc = "Recent files" })
  vim.keymap.set("n", "<leader>fh", fzf.helptags,   { desc = "Help tags" })
  vim.keymap.set("n", "<leader>fk", fzf.keymaps,    { desc = "Keymaps" })
  vim.keymap.set("n", "<leader>fm", fzf.marks,      { desc = "Marks" })
  vim.keymap.set("n", '<leader>f"', fzf.registers,  { desc = "Registers" })
  vim.keymap.set("n", "<leader>fc", fzf.commands,   { desc = "Commands" })

  -- fd: directory jumper (was `=`). fd+zoxide over /home /etc /root; the list
  -- shows the last 3-4 path components but cd's on the full path; closes every
  -- listed buffer on confirm, aborting with the offenders if any is dirty;
  -- rebroots NvimTree.
  vim.keymap.set("n", "<leader>fd", function()
    local cmd = "{ zoxide query --list 2>/dev/null;"
      .. " fd --type d --hidden --color never --absolute-path"
      .. " --exclude .git --exclude node_modules --exclude __pycache__ --exclude .cache"
      .. " . /home /etc /root 2>/dev/null; }"
      .. " | awk '!seen[$0]++'"
      .. [[ | awk -F'/' '{n=NF; label=""; for(i=(n>4?n-3:2);i<=n;i++) label=label"/"$i; if(n>4) label="..."label; print label"\t"$0}']]
    fzf.fzf_exec(cmd, {
      prompt = "cd> ",
      fzf_opts = {
        ["--delimiter"] = "\t",
        ["--with-nth"]  = "1",
      },
      actions = {
        ["default"] = function(sel)
          local dir = vim.trim((sel[1] or ""):match("\t(.+)$") or "")
          if dir == "" then return end

          local unsaved = {}
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.fn.buflisted(buf) == 1 and vim.bo[buf].modified then
              unsaved[#unsaved + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":~")
            end
          end
          if #unsaved > 0 then
            vim.notify("Unsaved buffers:\n  " .. table.concat(unsaved, "\n  "), vim.log.levels.WARN)
            return
          end

          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.fn.buflisted(buf) == 1 then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end

          vim.fn.jobstart({ "zoxide", "add", dir }, { detach = true })
          vim.cmd("cd " .. vim.fn.fnameescape(dir))
          local ok, api = pcall(require, "nvim-tree.api")
          if ok then api.tree.change_root(dir) end
          vim.notify(vim.fn.getcwd(), vim.log.levels.INFO)
        end,
      },
      winopts = { title = " Jump to directory " },
    })
  end, { silent = true, desc = "Directory jumper" })
end

-- =============================================================================
-- SEARCH
-- =============================================================================

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>",
  { silent = true, desc = "Clear search highlight" })

-- Keep cursor centered when jumping through search results
vim.keymap.set("n", "n", "nzzzv", { silent = true, desc = "Next search result (centred)" })
vim.keymap.set("n", "N", "Nzzzv", { silent = true, desc = "Prev search result (centred)" })

-- =============================================================================
-- TERMINAL
-- =============================================================================

-- <Esc><Esc> leaves terminal mode; a single <Esc> is passed straight through so
-- TUIs running in a terminal split (htop, REPLs, nested nvim, fzf) still receive
-- it. (Previously a lone <Esc> was mapped to <C-\><C-n>, which broke them.)
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>",
  { silent = true, desc = "Exit terminal mode" })
vim.keymap.set("n", "<leader>ot", "<cmd>rightbelow vsp | terminal<CR>",
  { silent = true, desc = "Terminal (right vsplit)" })
local env = require("config.env")

if env.has_kitty then
  vim.keymap.set("n", "<leader>ok", function()
    vim.fn.jobstart({ "setsid", "-f", "kitty", "--directory", vim.fn.expand("%:p:h") }, { detach = true })
  end, { silent = true, desc = "Spawn kitty here" })
end

-- New project: pick a generator (C++/ESP-IDF/Python/…), scaffold it, and re-root
-- into it. ONE key, registry-driven — adding a project type is a scaffold.lua
-- entry, never a bind (Axiom 5). Lazy-require so the registry isn't loaded until
-- first use.
vim.keymap.set("n", "<leader>op", function()
  require("config.scaffold").new_project()
end, { silent = true, desc = "New project" })

-- Open Claude Code in an adjacent kitty window rooted at the cwd.
if env.has_kitty then
  vim.keymap.set("n", "<leader>oc", function()
    if vim.fn.executable("claude") ~= 1 then
      vim.notify("claude not found", vim.log.levels.WARN)
      return
    end
    vim.fn.jobstart({ "setsid", "-f", "kitty", "--directory", vim.fn.getcwd(), "claude" }, { detach = true })
  end, { silent = true, desc = "Claude (cwd)" })
end

-- Ranger as a file picker rooted at the current dir. Runs in a centered float;
-- selecting file(s) (--choosefiles) opens them in nvim on exit instead of
-- ranger launching its own $EDITOR (which would nest another nvim).
vim.keymap.set("n", "<leader>or", function()
  if vim.fn.executable("ranger") ~= 1 then
    vim.notify("ranger not found", vim.log.levels.WARN)
    return
  end
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then dir = vim.fn.getcwd() end
  local choice = vim.fn.tempname()

  local buf = vim.api.nvim_create_buf(false, true)
  local w   = math.floor(vim.o.columns * 0.9)
  local h   = math.floor(vim.o.lines * 0.9)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width    = w,
    height   = h,
    row      = math.floor((vim.o.lines - h) / 2),
    col      = math.floor((vim.o.columns - w) / 2),
    style    = "minimal",
    border   = "rounded",
    title    = " ranger ",
  })

  vim.fn.jobstart({ "ranger", "--choosefiles=" .. choice, dir }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
      if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
      local ok_read, files = pcall(vim.fn.readfile, choice)
      if ok_read then
        for _, f in ipairs(files) do
          if f ~= "" then vim.cmd("edit " .. vim.fn.fnameescape(f)) end
        end
      end
      os.remove(choice)
    end,
  })
  vim.cmd("startinsert")
end, { silent = true, desc = "Ranger (current dir)" })

if env.has_kitty then
  vim.keymap.set("n", "<leader>be", function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
      vim.notify("Buffer has no file", vim.log.levels.WARN)
      return
    end
    if vim.bo.modified then
      vim.notify("Unsaved changes — save before ejecting", vim.log.levels.WARN)
      return
    end

    local ejected = vim.api.nvim_get_current_buf()
    local line    = vim.api.nvim_win_get_cursor(0)[1]

    -- Find a replacement buffer for any window currently showing the ejected one
    local alt = nil
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.fn.buflisted(b) == 1 and b ~= ejected then
        alt = b
        break
      end
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == ejected then
        if alt then
          vim.api.nvim_win_set_buf(win, alt)
        else
          vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
        end
      end
    end

    vim.fn.jobstart({ "setsid", "-f", "kitty", "nvim", "+" .. line, path }, { detach = true })
    vim.api.nvim_buf_delete(ejected, { force = false })
  end, { silent = true, desc = "Eject buffer to kitty" })
end

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

-- System clipboard (provider chosen in lua/config/clipboard.lua). Explicit "+ maps only — we do NOT
-- set clipboard=unnamedplus, so an ordinary y/p never touches the system
-- clipboard. <leader>y is a "+y operator, so it takes motions and works in
-- visual mode: <leader>yy (line), <leader>y$ (to EOL), etc. — which is why
-- there's no separate <leader>Y.
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { silent = true, desc = "Yank to clipboard" })
vim.keymap.set("n",          "<leader>p", '"+p', { silent = true, desc = "Paste after (clipboard)" })
vim.keymap.set("n",          "<leader>P", '"+P', { silent = true, desc = "Paste before (clipboard)" })
-- Visual paste: replace the selection with the clipboard while keeping "+
-- intact across repeated pastes. The replaced text lands in the unnamed
-- register (plain `d`), never back in "+.
vim.keymap.set("x", "<leader>p", 'd"+P', { silent = true, desc = "Paste over selection (clipboard)" })
vim.keymap.set("x", "<leader>P", 'd"+P', { silent = true, desc = "Paste over selection (clipboard)" })

-- =============================================================================
-- NAVIGATION
-- =============================================================================

-- C-h/j/k/l move between splits; at nvim's edge they hand off to the tmux
-- pane in that direction. The tmux half is vim-tmux-navigator in the dotfiles
-- tmux.conf, which forwards these keys to nvim when nvim is in the foreground.
local function navigate(dir)
  local win = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(dir)
  if vim.env.TMUX and vim.api.nvim_get_current_win() == win then
    local flag = ({ h = "-L", j = "-D", k = "-U", l = "-R" })[dir]
    vim.fn.system({ "tmux", "select-pane", "-t", vim.env.TMUX_PANE or "", flag })
  end
end
vim.keymap.set("n", "<C-h>", function() navigate("h") end, { silent = true, desc = "Window left (or tmux pane)" })
vim.keymap.set("n", "<C-j>", function() navigate("j") end, { silent = true, desc = "Window down (or tmux pane)" })
vim.keymap.set("n", "<C-k>", function() navigate("k") end, { silent = true, desc = "Window up (or tmux pane)" })
vim.keymap.set("n", "<C-l>", function() navigate("l") end, { silent = true, desc = "Window right (or tmux pane)" })

-- +Window: a discoverable mirror of the (now-restored) native <C-w> prefix.
-- Resize stays on native <C-w> +/-/</>.
vim.keymap.set("n", "<leader>wv", "<cmd>vsplit<cr>",  { silent = true, desc = "Vertical split" })
vim.keymap.set("n", "<leader>ws", "<cmd>split<cr>",   { silent = true, desc = "Horizontal split" })
vim.keymap.set("n", "<leader>wc", "<C-w>c",           { silent = true, desc = "Close window" })
vim.keymap.set("n", "<leader>wo", "<C-w>o",           { silent = true, desc = "Close other windows" })
vim.keymap.set("n", "<leader>w=", "<C-w>=",           { silent = true, desc = "Equalise windows" })
vim.keymap.set("n", "<leader>wx", "<C-w>x",           { silent = true, desc = "Swap windows" })
vim.keymap.set("n", "<leader>wT", "<C-w>T",           { silent = true, desc = "Move window to new tab" })

-- Mark the focused buffer as reference: hide it from the bufferline, return
-- focus to the main window (leaves the split visible as a reference pane).
vim.keymap.set("n", "<leader>wr", function()
  vim.bo.buflisted = false
  vim.cmd("wincmd p")
end, { silent = true, desc = "Mark as reference split" })

-- Keep cursor centered when scrolling half-pages
vim.keymap.set("n", "<C-d>", "<C-d>zz", { silent = true, desc = "Half-page down (centred)" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { silent = true, desc = "Half-page up (centred)" })

-- Drag selected lines up/down and re-indent
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move lines down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move lines up" })

-- =============================================================================
-- GIT
-- =============================================================================

-- Gitsigns — hunk-scoped actions (buffer-local). Shift = wider scope:
-- gs/gS stage hunk/buffer, gr/gR reset hunk/buffer.
local ok_gs, gs = pcall(require, "gitsigns")
if ok_gs then
  gs.setup({
    on_attach = function(bufnr)
      local o = function(desc) return { buffer = bufnr, desc = desc } end
      vim.keymap.set("n", "]c", function() gs.nav_hunk("next") end, o("Next hunk"))
      vim.keymap.set("n", "[c", function() gs.nav_hunk("prev") end, o("Prev hunk"))
      vim.keymap.set({ "n", "v" }, "<leader>gs", gs.stage_hunk,      o("Stage hunk"))
      vim.keymap.set("n", "<leader>gS", gs.stage_buffer,             o("Stage buffer"))
      vim.keymap.set("n", "<leader>gu", gs.undo_stage_hunk,          o("Undo stage hunk"))
      vim.keymap.set({ "n", "v" }, "<leader>gr", gs.reset_hunk,      o("Reset hunk"))
      vim.keymap.set("n", "<leader>gR", gs.reset_buffer,             o("Reset buffer"))
      vim.keymap.set("n", "<leader>gp", gs.preview_hunk,             o("Preview hunk"))
      -- One-shot blame popup for the current line (the virtual-text blame
      -- *toggle* is a different thing and lives at <leader>ub).
      vim.keymap.set("n", "<leader>gb", function() gs.blame_line({ full = true }) end,
        o("Blame line (popup)"))
      -- Diff: gd vs the index, gD vs a ref (prompt).
      vim.keymap.set("n", "<leader>gd", function() gs.diffthis() end, o("Diff vs index"))
      vim.keymap.set("n", "<leader>gD", function()
        vim.ui.input({ prompt = "Diff against ref: ", default = "HEAD" }, function(ref)
          if ref and ref ~= "" then gs.diffthis(ref) end
        end)
      end, o("Diff vs ref"))
    end,
  })
end

-- Repo-level git pickers (fzf) + lazygit. Global so they work without a
-- gitsigns attach.
local ok_gfzf, gfzf = pcall(require, "fzf-lua")
if ok_gfzf then
  vim.keymap.set("n", "<leader>gl", gfzf.git_commits,  { desc = "Commits" })
  vim.keymap.set("n", "<leader>gB", gfzf.git_branches, { desc = "Branches" })
  vim.keymap.set("n", "<leader>gh", gfzf.git_bcommits, { desc = "File history" })
end
vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { silent = true, desc = "Lazygit" })

-- =============================================================================
-- DIAGNOSTICS
-- =============================================================================

-- +Diagnostics (Trouble + fzf + quickfix)
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",
  { desc = "Workspace diagnostics" })
vim.keymap.set("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { desc = "Buffer diagnostics" })
vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>",  { desc = "Quickfix list" })
vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location list" })
vim.keymap.set("n", "<leader>xl", vim.diagnostic.open_float,         { desc = "Line diagnostics" })
do
  local ok_xfzf, xfzf = pcall(require, "fzf-lua")
  if ok_xfzf then
    vim.keymap.set("n", "<leader>xf", xfzf.diagnostics_document, { desc = "Fuzzy diagnostics" })
  end
end

-- Diagnostic navigation (0.11+ jump API; goto_next/prev are deprecated).
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end,
  { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end,
  { desc = "Prev diagnostic" })

-- Bare quickfix navigation — nothing walked the list that gr/grep populate.
vim.keymap.set("n", "]q", "<cmd>cnext<cr>",     { silent = true, desc = "Next quickfix" })
vim.keymap.set("n", "[q", "<cmd>cprevious<cr>", { silent = true, desc = "Prev quickfix" })

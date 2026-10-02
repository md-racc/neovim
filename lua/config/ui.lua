-- =============================================================================
-- SYNTAX
-- =============================================================================

-- Treesitter (main branch). The old master API (nvim-treesitter.configs,
-- ensure_installed/auto_install/highlight/indent flags) is gone: install() is
-- an async no-op for present parsers, and highlight + indent are started per
-- buffer below — nothing is enabled globally anymore.
local ok_ts, ts = pcall(require, "nvim-treesitter")
if ok_ts then
  -- Parsers this config guarantees (compiled via the tree-sitter CLI into
  -- stdpath("data")/site the first time, silently skipped afterwards).
  ts.install({
    "python", "cpp", "c", "lua", "bash",
    "latex", "markdown", "markdown_inline",
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("TreesitterAttach", { clear = true }),
    callback = function(args)
      local buf  = args.buf
      local lang = vim.treesitter.language.get_lang(args.match)
      if not lang then return end
      local function attach()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if not pcall(vim.treesitter.start, buf, lang) then return end
        -- Experimental upstream, but parity with the old indent={enable=true}.
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      if vim.treesitter.language.add(lang) then
        attach()
      elseif vim.tbl_contains(ts.get_available(), lang) then
        -- Parity with the old auto_install = true: fetch a missing parser on
        -- first use and attach once it lands.
        ts.install(lang):await(vim.schedule_wrap(attach))
      end
    end,
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
  render_markdown.setup({
    -- Disable anti-conceal entirely: by default it un-renders the cursor line
    -- back to raw markdown on every cursor move, causing flicker. Heading
    -- background/border virtual lines also disappear on the cursor line,
    -- shifting layout and causing jumps through complex files.
    anti_conceal = { enabled = false },
  })
end

-- =============================================================================
-- FILE TREE
-- =============================================================================

-- Nvim-tree
local ok_tree, nvim_tree = pcall(require, "nvim-tree")
if ok_tree then
  nvim_tree.setup({
    -- Hide dotfiles by default; toggle them back on in the tree with `H`.
    filters = { dotfiles = true },
    -- Safe delete: send to the freedesktop trash (recoverable) via gio.
    trash = { cmd = "gio trash" },
    -- Shorter, relative paths in the (now fnott-routed) notifications.
    notify = { absolute_path = false },
    on_attach = function(bufnr)
      local api = require("nvim-tree.api")
      api.config.mappings.default_on_attach(bufnr)
      vim.keymap.del("n", "<C-v>", { buffer = bufnr })

      -- Swap delete semantics so the reflexive key is the safe one:
      --   d → trash (recoverable), D → permanent remove.
      vim.keymap.set({ "n", "x" }, "d", api.fs.trash,
        { buffer = bufnr, nowait = true, desc = "Trash (recoverable)" })
      vim.keymap.set({ "n", "x" }, "D", api.fs.remove,
        { buffer = bufnr, nowait = true, desc = "Delete permanently" })

      -- <S-CR>: spawn a new adjacent kitty nvim instance.
      -- Directory → nvim opens with that dir as cwd.
      -- File      → nvim opens that file directly.
      vim.keymap.set("n", "<S-CR>", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        if node.type == "directory" then
          vim.fn.jobstart(
            { "setsid", "-f", "kitty", "--directory", node.absolute_path, "nvim" },
            { detach = true })
        else
          vim.fn.jobstart(
            { "setsid", "-f", "kitty", "nvim", node.absolute_path },
            { detach = true })
        end
      end, { buffer = bufnr, nowait = true, desc = "Open in new kitty nvim" })

      -- <C-CR>: directory → cd here for this instance + update tree root.
      --         file      → open in vertical split (no cwd analogue for files).
      vim.keymap.set("n", "<C-CR>", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        if node.type == "directory" then
          vim.cmd("cd " .. vim.fn.fnameescape(node.absolute_path))
          api.tree.change_root(node.absolute_path)
          vim.notify(vim.fn.getcwd(), vim.log.levels.INFO)
        else
          api.node.open.vertical()
        end
      end, { buffer = bufnr, nowait = true, desc = "cd to dir / open vsplit" })

      -- <BS>: cd up to parent directory and update tree root.
      vim.keymap.set("n", "<BS>", function()
        local parent = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
        vim.cmd("cd " .. vim.fn.fnameescape(parent))
        api.tree.change_root(parent)
        vim.notify(vim.fn.getcwd(), vim.log.levels.INFO)
      end, { buffer = bufnr, nowait = true, desc = "cd to parent directory" })

      -- <Tab>: preview file without moving focus away from the tree.
      vim.keymap.set("n", "<Tab>", api.node.open.preview,
        { buffer = bufnr, nowait = true, desc = "Preview file" })

      -- <CR>: dir → expand/collapse; file → open it as a real buffer in the
      -- editor window but keep focus in the tree (so you can keep browsing /
      -- opening more files without leaving it).
      vim.keymap.set("n", "<CR>", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        if node.type == "directory" then
          api.node.open.edit() -- default toggle for directories
        else
          api.node.open.edit() -- opens + focuses the file window
          vim.cmd("wincmd p")  -- ...then hop focus back to the tree
        end
      end, { buffer = bufnr, nowait = true, desc = "Open file (keep focus on tree)" })

      -- V-select multiple entries then <CR>: open all selected files, skip
      -- directories, return focus to the tree so you can keep browsing.
      vim.keymap.set("x", "<CR>", function()
        local start_line = vim.fn.line("'<")
        local end_line   = vim.fn.line("'>")
        for lnum = start_line, end_line do
          vim.api.nvim_win_set_cursor(0, { lnum, 0 })
          local node = api.tree.get_node_under_cursor()
          if node and node.type ~= "directory" then
            api.node.open.edit()
            vim.cmd("wincmd p") -- hop back to tree for next iteration
          end
        end
      end, { buffer = bufnr, nowait = true, desc = "Open selected files (keep tree focus)" })

      -- y: copy node's absolute path to system clipboard.
      pcall(vim.keymap.del, "n", "y", { buffer = bufnr })
      vim.keymap.set("n", "y", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        vim.fn.setreg("+", node.absolute_path)
        vim.notify("Copied: " .. node.absolute_path)
      end, { buffer = bufnr, nowait = true, desc = "Copy absolute path to clipboard" })

      -- Make <leader> work in the tree. mini.clue only auto-installs its
      -- triggers in listed / whitelisted buffers, so the (unlisted) NvimTree
      -- buffer never gets the <Leader> trigger and the leader query never starts
      -- there. Enable it explicitly, deferred so the trigger is the *latest*
      -- buffer-local mapping (mini.clue requires that, since we just created a
      -- pile of tree maps above).
      vim.schedule(function()
        local ok, clue = pcall(require, "mini.clue")
        if ok and clue.ensure_buf_triggers and vim.api.nvim_buf_is_valid(bufnr) then
          pcall(clue.ensure_buf_triggers, bufnr)
        end
      end)
    end,
  })
  vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
  -- Auto-open the tree on startup. Deferred with vim.schedule so it runs *after*
  -- persistence's own (nested) VimEnter session restore — otherwise the two
  -- collide into a duplicate tree / mangled layout. is_visible() guards against
  -- opening a second tree if a restored layout somehow already has one (it
  -- shouldn't: PersistenceSavePre closes the tree before the session is saved).
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.schedule(function()
        local api = require("nvim-tree.api")
        if api.tree.is_visible() then return end
        api.tree.open()
        -- Focus the editing window, not the tree (unless launched on a dir).
        if vim.fn.argc() == 0 or vim.fn.isdirectory(vim.fn.argv(0)) == 0 then
          vim.cmd("wincmd p")
        end
      end)
    end,
  })
end

-- =============================================================================
-- STATUSLINE
-- =============================================================================

-- Lualine
--
-- The theme is derived from the live highlight groups instead of lualine's
-- per-colorscheme theme file (lackluster ships one with hardcoded greys that the
-- wallust overlay never touches). Sections are transparent like StatusLine; only
-- the mode pill is filled, using the same syntax roles as the overlay:
-- normal=Function (color4), insert=String (color2), visual=Statement (color5),
-- replace=Constant (color1), command=Special (color3), terminal=Type (color6).
local function hl_color(group, attr, fallback)
  local h = vim.api.nvim_get_hl(0, { name = group, link = false })
  return h[attr] and string.format("#%06x", h[attr]) or fallback
end

local function lualine_theme()
  local fg    = hl_color("Normal", "fg", "#cccccc")
  local muted = hl_color("Comment", "fg", fg)
  -- Text on the pill: the scheme's base (Normal bg is "none" — transparent)
  local ink   = hl_color("Normal", "bg", nil) or hl_color("NormalFloat", "bg", "#000000")
  local function mode(group)
    return {
      a = { fg = ink, bg = hl_color(group, "fg", fg), gui = "bold" },
      b = { fg = fg,  bg = "NONE" },
      c = { fg = fg,  bg = "NONE" },
    }
  end
  return {
    normal   = mode("Function"),
    insert   = mode("String"),
    visual   = mode("Statement"),
    replace  = mode("Constant"),
    command  = mode("Special"),
    terminal = mode("Type"),
    inactive = {
      a = { fg = muted, bg = "NONE", gui = "bold" },
      b = { fg = muted, bg = "NONE" },
      c = { fg = muted, bg = "NONE" },
    },
  }
end

local ok_ll, lualine = pcall(require, "lualine")
if ok_ll then
  lualine.setup({
    options = {
      theme               = lualine_theme,
      globalstatus        = true,
      section_separators   = { left = "|", right = "|" },
      component_separators = { left = "|", right = "|" },
    },
  })

  -- lualine's own ColorScheme hook re-runs the theme function, but it fires
  -- before the wallust overlay autocmd (registered later in init.lua), and a
  -- light overlay reloads the base colorscheme mid-handler. Rebuild once more
  -- after every ColorScheme handler has settled so the bar reads final colors.
  local pending = false
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      if pending then return end
      pending = true
      vim.schedule(function()
        pending = false
        lualine.setup()
      end)
    end,
  })
end

-- =============================================================================
-- TABS
-- =============================================================================

-- Bufferline
--
-- Per-instance tag: a free-text label shown in the top-right of the tab bar so
-- multiple nvim instances (often same project, different branches) are easy to
-- tell apart. Set it with `:Tag <name>` or <leader>I. Named "NvimTag"
-- (uppercase-first, has a lowercase letter) so it qualifies for session
-- `globals` persistence — it's saved/restored with named workspaces and the
-- auto-saved session (see sessionoptions += globals in init.lua).
vim.g.NvimTag = vim.g.NvimTag or ""

local ok_bl, bufferline = pcall(require, "bufferline")
if ok_bl then
  bufferline.setup({
    options = {
      offsets = { { filetype = "NvimTree", text = "Files", highlight = "Directory" } },
      custom_areas = {
        right = function()
          if vim.g.NvimTag == "" then return {} end
          return { { text = "  ⟦ " .. vim.g.NvimTag .. " ⟧  ", link = "Function" } }
        end,
      },
    },
  })

  vim.api.nvim_create_user_command("Tag", function(o)
    if o.args ~= "" then
      vim.g.NvimTag = o.args
      vim.cmd("redrawtabline")
    else
      vim.ui.input({ prompt = "Instance tag: ", default = vim.g.NvimTag }, function(input)
        if input == nil then return end
        vim.g.NvimTag = input
        vim.cmd("redrawtabline")
        -- Clear the prompt+entry that input() leaves echoed on the command line.
        vim.schedule(function() vim.api.nvim_echo({ { "" } }, false, {}) end)
      end)
    end
  end, { nargs = "?", desc = "Set this instance's tab tag" })

  vim.keymap.set("n", "<leader>st", "<cmd>Tag<cr>", { desc = "Set instance tag" })
end

-- +Buffer. Close switches away first so the split that showed the buffer keeps
-- a buffer instead of collapsing. force=false respects unsaved changes (errors);
-- force=true (bD) discards them.
local function smart_bdelete(force)
  local cur     = vim.api.nvim_get_current_buf()
  -- A terminal always needs bdelete! (its job is "modified"); killing the shell
  -- is the expected outcome of closing it, so bd force-closes terminals too.
  -- The unsaved-changes guard only protects real file buffers.
  local is_term = vim.bo[cur].buftype == "terminal"
  if not force and not is_term and vim.bo[cur].modified then
    vim.notify("Unsaved changes (use <leader>bD to force)", vim.log.levels.WARN)
    return
  end
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
  vim.cmd(((force or is_term) and "bdelete! " or "bdelete ") .. cur)
end

vim.keymap.set("n", "<leader>bd", function() smart_bdelete(false) end, { silent = true, desc = "Close buffer" })
vim.keymap.set("n", "<leader>bD", function() smart_bdelete(true) end,  { silent = true, desc = "Force close buffer" })
vim.keymap.set("n", "<leader>bn", "<cmd>enew<cr>",                     { silent = true, desc = "New buffer" })
vim.keymap.set("n", "<leader>bo", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(b) == 1 and b ~= cur
      and not vim.startswith(vim.fn.bufname(b), "NvimTree")
      and not vim.bo[b].modified then
      pcall(vim.cmd, "bdelete " .. b)
    end
  end
end, { silent = true, desc = "Close other buffers" })
vim.keymap.set("n", "<leader>ba", function()
  -- Abort (listing the offenders) if any real buffer has unsaved changes;
  -- otherwise close every listed buffer and drop to a blank slate. Terminals
  -- force-close (their job counts as modified); the tree is left alone.
  local targets, unsaved = {}, {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(b) == 1 and not vim.startswith(vim.fn.bufname(b), "NvimTree") then
      if vim.bo[b].buftype == "" and vim.bo[b].modified then
        unsaved[#unsaved + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":~")
      else
        targets[#targets + 1] = b
      end
    end
  end
  if #unsaved > 0 then
    vim.notify("Unsaved buffers — aborting:\n  " .. table.concat(unsaved, "\n  "),
      vim.log.levels.WARN)
    return
  end
  vim.cmd("enew") -- blank slate so windows don't collapse as buffers close
  for _, b in ipairs(targets) do
    pcall(vim.cmd, (vim.bo[b].buftype == "terminal" and "bdelete! " or "bdelete ") .. b)
  end
end, { silent = true, desc = "Close all buffers" })
vim.keymap.set("n", "<leader>by", function()
  local p = vim.api.nvim_buf_get_name(0)
  if p == "" then vim.notify("Buffer has no file", vim.log.levels.WARN); return end
  vim.fn.setreg("+", p); vim.notify("Copied: " .. p)
end, { desc = "Copy absolute path" })
vim.keymap.set("n", "<leader>bY", function()
  local p = vim.fn.expand("%")
  if p == "" then vim.notify("Buffer has no file", vim.log.levels.WARN); return end
  vim.fn.setreg("+", p); vim.notify("Copied: " .. p)
end, { desc = "Copy relative path" })
vim.keymap.set("n", "<leader>bw", "<cmd>SudaWrite<cr>", { desc = "Sudo write" })
vim.keymap.set("n", "<leader>br", "<cmd>SudaRead<cr>",  { desc = "Sudo re-read" })

for i = 1, 9 do
  vim.keymap.set("n", "<M-" .. i .. ">", function()
    if not vim.bo.buflisted then vim.cmd("wincmd p") end
    vim.cmd("BufferLineGoToBuffer " .. i)
  end, { silent = true, desc = "Go to buffer " .. i })
end

-- =============================================================================
-- WHICH-KEY  [DEPRECATED — inactive scaffolding]
-- =============================================================================
-- mini.clue (below) is the active leader-hint UI. which-key is kept only as
-- dormant scaffolding: its popup is disabled (triggers = {}) and the
-- which_key.add() group registrations no longer drive any UI. Retained so
-- reverting to which-key is a one-line change; safe to delete this whole block
-- (and the which-key plugin spec in init.lua) once mini.clue has proven itself.

local ok_wk, which_key = pcall(require, "which-key")
if ok_wk then
  -- Popup disabled; see the DEPRECATED banner above.
  which_key.setup({
    triggers = {}, -- do not intercept any key; never show the popup
    show_keys = false,
  })
  -- Icons are built from explicit Material Design Nerd Font codepoints via
  -- nr2char so no glyph can be lost/blanked in the source file (which is what
  -- happened before to the non-MD group icons). Every top-level leader entry —
  -- the 12 groups and each hot-tier bare action — gets one.
  local ic = function(cp) return vim.fn.nr2char(cp) end
  which_key.add({
    -- The 12 domain groups. `l` (+language) is registered per-buffer by
    -- lua/lang/init.lua (and the tex autocmd), so it re-labels itself as +C++,
    -- +Python, +LaTeX, ... and stays absent where no language module matched.
    { "<leader>b", group = "Buffer",       icon = ic(0xF04E9) }, -- tabs
    { "<leader>c", group = "Code",         icon = ic(0xF0169) }, -- code-braces
    { "<leader>d", group = "Debug",        icon = ic(0xF00E4) }, -- bug
    { "<leader>f", group = "Find",         icon = ic(0xF0349) }, -- magnify
    { "<leader>g", group = "Git",          icon = ic(0xF02A2) }, -- git
    { "<leader>o", group = "Open",         icon = ic(0xF024B) }, -- folder
    { "<leader>s", group = "Session",      icon = ic(0xF0193) }, -- content-save
    { "<leader>t", group = "Test",         icon = ic(0xF0668) }, -- test-tube
    { "<leader>u", group = "UI / Toggles", icon = ic(0xF0493) }, -- cog
    { "<leader>w", group = "Window",       icon = ic(0xF05AF) }, -- window-maximize
    { "<leader>x", group = "Diagnostics",  icon = ic(0xF002A) }, -- alert
    -- Hot-tier bare actions.
    { "<leader><leader>", icon = ic(0xF0450) }, -- refresh (resume picker)
    { "<leader>e", icon = ic(0xF0645) },        -- file-tree
    { "<leader>y", icon = ic(0xF014E) },        -- content-copy
    { "<leader>p", icon = ic(0xF0192) },        -- clipboard-arrow-down
    { "<leader>P", icon = ic(0xF0192) },
    { "<leader>q", icon = ic(0xF0206) },        -- exit-to-app
    { "<leader>Q", icon = ic(0xF0206) },
  })
end

-- =============================================================================
-- LEADER-HINT UI — mini.clue (discreet, resize-robust replacement for the
-- which-key popup). Leaf hints come from each mapping's `desc` automatically;
-- we only declare the group-prefix labels + the builtin clue sets.
-- =============================================================================

local ok_clue, MiniClue = pcall(require, "mini.clue")
if ok_clue then
  local g = MiniClue.gen_clues
  -- mini.clue has no icon system (it renders a plain ` key │ desc` line), so we
  -- bake a Material Design glyph into each *group* desc. Leaf rows stay plain
  -- text — that keeps them coming straight from each mapping's `desc` (and keeps
  -- the generated KEYBINDS.md glyph-free).
  local ic = function(cp) return vim.fn.nr2char(cp) .. " " end
  MiniClue.setup({
    triggers = {
      -- Leader (normal + visual; we have x-mode leader maps too).
      { mode = "n", keys = "<Leader>" },
      { mode = "x", keys = "<Leader>" },
      -- Builtins worth hinting.
      { mode = "n", keys = "g" },
      { mode = "x", keys = "g" },
      { mode = "n", keys = "z" },
      { mode = "n", keys = "]" },
      { mode = "n", keys = "[" },
      { mode = "n", keys = "<C-w>" }, -- native window prefix (restored)
      { mode = "n", keys = '"' },     -- registers
      { mode = "x", keys = '"' },
      { mode = "i", keys = "<C-r>" },
      { mode = "n", keys = "'" },     -- marks
      { mode = "n", keys = "`" },
    },
    clues = {
      g.builtin_completion(),
      g.g(),
      g.marks(),
      g.registers(),
      g.windows(),
      g.z(),
      -- Our 12 leader groups (mirror of the which-key scaffolding above).
      { mode = "n", keys = "<Leader>b", desc = ic(0xF04E9) .. "+Buffer" },
      { mode = "n", keys = "<Leader>c", desc = ic(0xF0169) .. "+Code" },
      { mode = "n", keys = "<Leader>d", desc = ic(0xF00E4) .. "+Debug" },
      { mode = "n", keys = "<Leader>f", desc = ic(0xF0349) .. "+Find" },
      { mode = "n", keys = "<Leader>g", desc = ic(0xF02A2) .. "+Git" },
      -- <Leader>l (+C++, +Python, +LaTeX, ...) and its depth-3 sub-groups
      -- (+CMake, +Flash/Device) are NOT declared here: mini.clue shows
      -- clue-only entries as available keys, so a global label would surface
      -- phantom rows in buffers that lack those maps. The language dispatcher
      -- (lua/lang/init.lua) and the tex autocmd set them per buffer via
      -- vim.b.miniclue_config instead.
      { mode = "n", keys = "<Leader>o", desc = ic(0xF024B) .. "+Open" },
      { mode = "n", keys = "<Leader>s", desc = ic(0xF0193) .. "+Session" },
      { mode = "n", keys = "<Leader>t", desc = ic(0xF0668) .. "+Test" },
      { mode = "n", keys = "<Leader>u", desc = ic(0xF0493) .. "+UI/Toggles" },
      { mode = "n", keys = "<Leader>w", desc = ic(0xF05AF) .. "+Window" },
      { mode = "n", keys = "<Leader>x", desc = ic(0xF002A) .. "+Diagnostics" },
    },
    window = {
      delay  = 400,
      config = { border = "rounded" },
    },
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

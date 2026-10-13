-- =============================================================================
-- OPTIONS
-- =============================================================================

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- Display
vim.opt.number         = true
vim.opt.relativenumber = false
vim.opt.showcmd        = true
vim.opt.showmatch      = true
vim.opt.matchpairs:append("<:>")
vim.opt.scrolloff      = 10
vim.opt.wrap           = false
vim.opt.termguicolors  = true
vim.opt.background     = "dark"
vim.opt.cmdheight      = 1
-- Always reserve the sign gutter so the first gitsigns/diagnostic sign doesn't
-- shift the whole buffer text sideways.
vim.opt.signcolumn     = "yes"
vim.opt.guicursor      = "n-v-c:ver25-blinkon500-blinkoff500,i-ci:ver25-blinkon500-blinkoff500"

-- Indentation
vim.opt.expandtab  = true
vim.opt.shiftwidth = 2
vim.opt.tabstop    = 2

-- Search
vim.opt.ignorecase  = true
vim.opt.smartcase   = true
vim.opt.inccommand  = "split"

-- Splits
vim.opt.splitright = true

-- Persistence
vim.opt.undofile   = true
vim.opt.undolevels = 10000

-- Behavior
vim.opt.autoread   = true
vim.opt.mouse      = "a"
vim.opt.updatetime = 300
-- Persist qualifying global vars (e.g. g:NvimTag) in sessions/workspaces.
vim.opt.sessionoptions:append("globals")

-- Clipboard provider: wl-clipboard locally, tmux / OSC 52 over ssh
require("config.clipboard")

-- Reload file if changed outside Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  callback = function()
    if vim.fn.mode() ~= "c" then vim.cmd("checktime") end
  end,
})

-- =============================================================================
-- APPEARANCE
-- =============================================================================

-- Keep background transparent to let the terminal compositor show through
local function apply_transparency()
  local transparent = {
    "Normal", "StatusLine", "StatusLineNC",
    "WinSeparator", "NvimTreeNormal", "NvimTreeNormalNC", "TroubleNormal",
  }
  for _, group in ipairs(transparent) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
  -- Floats (hover, diagnostics): distinct background with lackluster 'lack' border
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#2a2a2a", fg = "#cccccc" })
  vim.api.nvim_set_hl(0, "FloatBorder", { bg = "#2a2a2a", fg = "#708090" })

  -- (which-key's popup is permanently disabled — mini.clue is the active
  -- leader-hint UI — so its highlight groups are no longer set here.)
  -- Completion menu
  vim.api.nvim_set_hl(0, "Pmenu",      { bg = "#252525", fg = "#c0c0c0" })
  vim.api.nvim_set_hl(0, "PmenuSel",   { bg = "#3c3c3c", fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "PmenuSbar",  { bg = "#252525" })
  vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "#555555" })
end
apply_transparency()
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_transparency })

-- =============================================================================
-- PROVIDERS
-- =============================================================================

-- Disable unused providers to avoid healthcheck warnings
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- =============================================================================
-- PLUGINS
-- =============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- LSP
  { "neovim/nvim-lspconfig" },

  -- Completion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },

  -- Treesitter (main branch — the frozen master API is gone; parsers install
  -- via the tree-sitter CLI and highlight/indent are started per buffer in
  -- lua/config/ui.lua).
  { "nvim-treesitter/nvim-treesitter", branch = "main", build = ":TSUpdate" },

  { "nvim-lua/plenary.nvim" },
  { "ibhagwan/fzf-lua", dependencies = { "nvim-tree/nvim-web-devicons" } },

  -- Theme
  {
    "slugbyte/lackluster.nvim",
    priority = 1000,
    config = function()
      local ok, lackluster = pcall(require, "lackluster")
      if ok then
        lackluster.setup({
          tweak_color = {
            black = "#1a1a1a", gray1 = "#202020", gray2 = "#2a2a2a", gray3 = "#333333",
          },
        })
      end
      vim.cmd("colorscheme lackluster")
    end,
  },

  -- UI
  { "nvim-tree/nvim-tree.lua" },
  { "nvim-lualine/lualine.nvim",                dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "akinsho/bufferline.nvim",                  dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "lukas-reineke/indent-blankline.nvim",       main = "ibl" },
  -- DEPRECATED: which-key is dormant scaffolding only — its popup is disabled
  -- (triggers = {} in lua/config/ui.lua) and mini.clue is the active hint UI.
  -- Kept for a one-line revert; safe to remove once mini.clue has proven itself.
  { "folke/which-key.nvim" },
  -- mini.clue is the active leader-hint UI (lighter + more resize-robust than
  -- which-key on Hyprland, which mispositions on frequent VimResized events).
  { "echasnovski/mini.clue", version = false },
  { "folke/trouble.nvim",                        dependencies = { "nvim-tree/nvim-web-devicons" }, config = true },
  { "MeanderingProgrammer/render-markdown.nvim", dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" } },

  -- Git
  { "lewis6991/gitsigns.nvim" },
  { "kdheepak/lazygit.nvim",   dependencies = { "nvim-lua/plenary.nvim" } },

  -- Session persistence (auto-save on quit, auto-restore on open). All the
  -- session/workspace logic lives in lua/config/session.lua; it's loaded from
  -- here (not the bottom require block) so persistence is available to it.
  {
    "folke/persistence.nvim",
    config = function() require("config.session") end,
  },

  -- Sudo read/write via PAM auth (keybinds in editor.lua)
  { "lambdalisue/suda.vim" },

  -- Color highlighter (renders #hex / rgb() / rgba() in their actual color)
  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {
      user_default_options = {
        RGB      = true,
        RRGGBB   = true,
        names    = false,
        RRGGBBAA = true,
        rgb_fn   = true,
        hsl_fn   = true,
        css      = true,
      },
    },
  },

  -- Kitty integration: opens the scrollback (or last command's output) in a
  -- real nvim buffer for keyboard-driven select/search/yank. Lazy-loaded —
  -- only activates when kitty launches nvim in scrollback mode (kitty.conf
  -- kitty_mod+h / kitty_mod+g), never on a normal nvim startup.
  {
    "mikesmithgh/kitty-scrollback.nvim",
    lazy = true,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth", "KittyScrollbackGenerateCommandLineEditing" },
    event = { "User KittyScrollbackLaunch" },
    config = function() require("kitty-scrollback").setup() end,
  },

  -- Editor tools
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = false,
      view_options = { show_hidden = true },
      delete_to_trash = true,
    },
    keys = {
      { "-",          "<cmd>Oil<cr>", desc = "Open parent directory" },
      { "<leader>oo", "<cmd>Oil<cr>", desc = "Oil (current dir)" },
    },
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s",     function() require("flash").jump() end,              desc = "Flash jump",             mode = { "n", "x", "o" } },
      { "S",     function() require("flash").treesitter() end,        desc = "Flash treesitter",       mode = { "n", "x", "o" } },
      { "r",     function() require("flash").remote() end,            desc = "Flash remote",           mode = "o" },
      { "R",     function() require("flash").treesitter_search() end, desc = "Flash treesitter search",mode = { "o", "x" } },
    },
  },
  { "windwp/nvim-autopairs" },
  { "kylechui/nvim-surround", version = "*" },
  { "stevearc/conform.nvim" },
  {
    "numToStr/Comment.nvim",
    dependencies = { "JoosepAlviste/nvim-ts-context-commentstring" },
    config = function()
      require("ts_context_commentstring").setup({ enable_autocmd = false })
      require("Comment").setup({
        pre_hook = function(ctx)
          local cs = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()(ctx)
          return cs ~= nil and cs or vim.bo.commentstring
        end,
      })
    end,
  },

  -- C++ tools (lazy: loaded when opening c/cpp files)
  { "p00f/clangd_extensions.nvim", ft = { "c", "cpp" }, config = true },
  {
    -- Generate out-of-line definition stubs from header declarations and copy
    -- them to the clipboard. The keymaps that drive this (ld / l3 / l5) live in
    -- the buffer-local C++ language module (lua/lang/cpp.lua); here we only
    -- define the command they invoke.
    "Badhi/nvim-treesitter-cpp-tools",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "c", "cpp" },
    config = function()
      -- output_handle only takes effect via a custom command. Ours copies the
      -- generated definitions to the clipboard instead of inserting them.
      require("nt-cpp-tools").setup({
        header_extension = "h",
        source_extension = "cpp",
        custom_define_class_function_commands = {
          TSCppYankImpl = {
            output_handle = function(str, _)
              -- The plugin emits Allman braces (`sig\n{\n}`); rewrite to attach
              -- style (`sig {\n}`) so it matches clang-format's LLVM default and
              -- a save-time reformat is a no-op. Mirrors the stub hook in
              -- lua/config/completion.lua.
              str = str:gsub("\n{\n}", " {\n}")
              vim.fn.setreg("+", str) -- system clipboard
              vim.fn.setreg('"', str) -- unnamed, so plain `p` pastes it
              local n = select(2, str:gsub("}", ""))
              vim.notify(("Copied %d definition(s) to clipboard"):format(n))
            end,
          },
        },
      })
    end,
  },
  {
    -- Keymaps (lm* CMake sub-group) live in lua/lang/cpp.lua; the plugin only
    -- needs to be loaded so the :CMake* commands exist.
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "c", "cpp", "cmake" },
    config = function()
      require("cmake-tools").setup({})
    end,
  },

  -- Testing (Neotest). neotest-gtest covers the C++ side (GoogleTest / ctest);
  -- neotest-python covers pytest/unittest.
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-python",
      "alfaix/neotest-gtest",
    },
    config = function() require("config.testing") end,
  },

  -- Debugging (lazy: loaded on first keymap use)
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    keys = {
      { "<F5>",       desc = "Debug: continue" },
      { "<F10>",      desc = "Debug: step over" },
      { "<F11>",      desc = "Debug: step into" },
      { "<F12>",      desc = "Debug: step out" },
      { "<leader>db", desc = "Toggle breakpoint" },
      { "<leader>dB", desc = "Conditional breakpoint" },
      { "<leader>dc", desc = "Continue" },
      { "<leader>di", desc = "Step into" },
      { "<leader>do", desc = "Step over" },
      { "<leader>dO", desc = "Step out" },
      { "<leader>dr", desc = "DAP REPL" },
      { "<leader>du", desc = "Toggle DAP UI" },
      { "<leader>dt", desc = "Terminate session" },
      { "<leader>ut", desc = "Toggle DAP virtual text" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function() require("config.dap") end,
  },

  -- STM32 on-chip debug adapter (wraps VS Code's cortex-debug; needs Node).
  -- Loaded on c/cpp so it's available when dap.lua calls require("dap-cortex-debug");
  -- a missing Node degrades gracefully (dap.lua guards the setup with pcall).
  {
    "jedrzejboczar/nvim-dap-cortex-debug",
    ft = { "c", "cpp" },
    dependencies = { "mfussenegger/nvim-dap" },
  },

  -- Code outline
  {
    "stevearc/aerial.nvim",
    event = "LspAttach",
    keys = { { "<leader>uo", "<cmd>AerialToggle<cr>", desc = "Toggle code outline" } },
    config = function() require("config.aerial") end,
  },

  -- LaTeX
  {
    "lervag/vimtex",
    ft = "tex",
    init = function()
      vim.g.vimtex_view_method      = "zathura"
      vim.g.vimtex_compiler_method  = "latexmk"
      vim.g.vimtex_quickfix_mode    = 0
      vim.g.vimtex_mappings_enabled = 1
    end,
  },
  { "micangl/cmp-vimtex" },

  -- CSV / TSV — column-aligned view via virtual text (file on disk untouched).
  -- Configured + bound from lua/lang/csv.lua; .xlsx opens through the same
  -- path as a read-only csv buffer (lua/lang/xlsx.lua).
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  },

}, {
  rocks = { enabled = false, hererocks = false },
})

require("config.notify")
require("config.ui")
require("config.filemgmt")
require("config.editor")
require("config.lsp")
require("config.completion")
require("config.autocmds")
require("config.toggles")
require("lang")

-- wallust color overlay — pull based, no-op on devices without wallust
local _wc = vim.fn.expand("~/.cache/wallust/nvim-colors.lua")
if vim.fn.filereadable(_wc) == 1 then
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function() pcall(dofile, _wc) end,
  })
  -- Apply via the ColorScheme event (not a bare dofile) so everything that
  -- derives colors from highlights (lualine theme, ...) sees the overlay at startup.
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
  -- Re-apply whenever wallust regenerates the file (live theme switching).
  -- Watch the PARENT DIRECTORY, not the file itself: wallust regenerates via
  -- write-then-rename (an atomic replace), which swaps the file's inode. A
  -- watch bound to the file's own path stays on the old, now-orphaned inode
  -- and silently stops firing after the first regeneration; the directory's
  -- inode is stable, so this keeps working across every future replace.
  local _wc_dir  = vim.fn.fnamemodify(_wc, ":h")
  local _wc_name = vim.fn.fnamemodify(_wc, ":t")
  local _watcher = vim.uv.new_fs_event()
  if _watcher then
    _watcher:start(_wc_dir, {}, vim.schedule_wrap(function(_, filename)
      if filename ~= _wc_name then return end
      pcall(dofile, _wc)
      vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
    end))
  end
end

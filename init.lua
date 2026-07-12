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

-- Explicit wl-clipboard provider (bypasses WAYLAND_DISPLAY detection)
vim.g.clipboard = {
  name  = "wl-clipboard",
  copy  = { ["+"] = "wl-copy",                    ["*"] = "wl-copy" },
  paste = { ["+"] = "wl-paste --no-newline",       ["*"] = "wl-paste --no-newline" },
  cache_enabled = 0,
}

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

  -- Which-key: hierarchy using lackluster's own palette
  vim.api.nvim_set_hl(0, "WhichKeyFloat",  { bg = "#2a2a2a" })
  vim.api.nvim_set_hl(0, "WhichKeyBorder", { bg = "#2a2a2a", fg = "#708090" })
  vim.api.nvim_set_hl(0, "WhichKey",       { fg = "#cccccc", bold = true })
  vim.api.nvim_set_hl(0, "WhichKeySep",    { fg = "#555555" })
  vim.api.nvim_set_hl(0, "WhichKeyDesc",   { fg = "#aaaaaa" })
  vim.api.nvim_set_hl(0, "WhichKeyGroup",  { fg = "#7788AA", bold = true })
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
if not vim.loop.fs_stat(lazypath) then
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

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

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
  { "folke/which-key.nvim" },
  { "folke/trouble.nvim",                        dependencies = { "nvim-tree/nvim-web-devicons" }, config = true },
  { "MeanderingProgrammer/render-markdown.nvim", dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" } },

  -- Git
  { "lewis6991/gitsigns.nvim" },
  { "kdheepak/lazygit.nvim",   dependencies = { "nvim-lua/plenary.nvim" } },

  -- Session persistence (auto-save on quit, auto-restore on open)
  {
    "folke/persistence.nvim",
    config = function()
      require("persistence").setup()
      -- Close nvim-tree before the session is written so it is never saved as a
      -- window. Otherwise restoring re-creates a tree window on top of the one
      -- the VimEnter autocmd opens, loading the tree twice.
      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = function() pcall(vim.cmd, "NvimTreeClose") end,
      })
      -- Restore session when nvim is opened in a directory with no file args
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = function()
          if vim.fn.argc() == 0 then require("persistence").load() end
        end,
      })
      vim.keymap.set("n", "<leader>Sl", function() require("persistence").load() end,
        { silent = true, desc = "Load session for cwd" })
      vim.keymap.set("n", "<leader>Ss", function() require("persistence").stop() end,
        { silent = true, desc = "Stop saving session (discard on quit)" })

      -- Named workspaces: save and restore by name across any directory
      local ws_dir = vim.fn.stdpath("data") .. "/workspaces/"
      vim.fn.mkdir(ws_dir, "p")

      vim.keymap.set("n", "<leader>Sw", function()
        vim.ui.input({ prompt = "Workspace name: " }, function(name)
          if not name or name == "" then return end
          -- Don't capture the tree window in the session (see PersistenceSavePre).
          local tree = require("nvim-tree.api").tree
          local reopen = tree.is_visible()
          if reopen then vim.cmd("NvimTreeClose") end
          vim.cmd("mksession! " .. vim.fn.fnameescape(ws_dir .. name .. ".vim"))
          if reopen then tree.open() end
          vim.notify("Workspace saved: " .. name)
        end)
      end, { desc = "Save named workspace" })

      vim.keymap.set("n", "<leader>So", function()
        local files = vim.fn.globpath(ws_dir, "*.vim", false, true)
        if #files == 0 then vim.notify("No saved workspaces"); return end
        local names = vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ":t:r") end, files)
        local ok, fzf = pcall(require, "fzf-lua")
        if ok then
          fzf.fzf_exec(names, {
            prompt = "Workspace> ",
            actions = {
              ["default"] = function(sel)
                if sel and sel[1] then
                  vim.cmd("source " .. vim.fn.fnameescape(ws_dir .. sel[1] .. ".vim"))
                end
              end,
            },
          })
        else
          vim.ui.select(names, { prompt = "Load workspace:" }, function(name)
            if name then vim.cmd("source " .. vim.fn.fnameescape(ws_dir .. name .. ".vim")) end
          end)
        end
      end, { desc = "Open named workspace" })
    end,
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
      { "-", "<cmd>Oil<cr>", desc = "Open parent directory" },
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
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "c", "cpp", "cmake" },
    config = function()
      require("cmake-tools").setup({})
      vim.keymap.set("n", "<leader>mb", "<cmd>CMakeBuild<cr>",              { desc = "CMake build" })
      vim.keymap.set("n", "<leader>mr", "<cmd>CMakeRun<cr>",                { desc = "CMake run" })
      vim.keymap.set("n", "<leader>md", "<cmd>CMakeDebug<cr>",              { desc = "CMake debug" })
      vim.keymap.set("n", "<leader>ms", "<cmd>CMakeSelectBuildType<cr>",    { desc = "Select build type" })
      vim.keymap.set("n", "<leader>mt", "<cmd>CMakeSelectLaunchTarget<cr>", { desc = "Select launch target" })
    end,
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
      { "<leader>Db", desc = "Toggle breakpoint" },
      { "<leader>DB", desc = "Conditional breakpoint" },
      { "<leader>Dr", desc = "Open DAP REPL" },
      { "<leader>Du", desc = "Toggle DAP UI" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
    },
    config = function() require("config.dap") end,
  },

  -- Code outline
  {
    "stevearc/aerial.nvim",
    event = "LspAttach",
    keys = { { "<leader>o", "<cmd>AerialToggle<cr>", desc = "Toggle code outline" } },
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

-- wallust color overlay — pull based, no-op on devices without wallust
local _wc = vim.fn.expand("~/.cache/wallust/nvim-colors.lua")
if vim.fn.filereadable(_wc) == 1 then
  pcall(dofile, _wc)
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function() pcall(dofile, _wc) end,
  })
  -- re-apply whenever wallust regenerates the file (live theme switching)
  local _watcher = vim.uv.new_fs_event()
  _watcher:start(_wc, {}, vim.schedule_wrap(function()
    pcall(dofile, _wc)
    vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
  end))
end

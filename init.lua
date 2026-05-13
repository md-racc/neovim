-- Options
vim.opt.autoread       = true
vim.opt.mouse          = "a"
vim.opt.clipboard      = "unnamedplus"
vim.opt.termguicolors  = true
vim.opt.background     = "dark"
vim.opt.cmdheight      = 1
vim.opt.showcmd        = true
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.splitright     = true
vim.opt.scrolloff      = 10
vim.opt.wrap           = false
vim.opt.undofile       = true
vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.guicursor      = "n-v-c:ver25-blinkon500-blinkoff500,i-ci:ver25-blinkon500-blinkoff500"

-- Reload file if changed outside Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  callback = function()
    if vim.fn.mode() ~= "c" then vim.cmd("checktime") end
  end,
})

-- Keep background transparent to let the terminal compositor show through
local function apply_transparency()
  local groups = {
    "Normal", "NormalFloat", "FloatBorder", "StatusLine", "StatusLineNC",
    "WinSeparator", "NvimTreeNormal", "NvimTreeNormalNC",
    "TelescopeNormal", "TelescopeBorder", "TroubleNormal",
  }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
  vim.api.nvim_set_hl(0, "Pmenu",      { bg = "#252525", fg = "#c0c0c0" })
  vim.api.nvim_set_hl(0, "PmenuSel",   { bg = "#3c3c3c", fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "PmenuSbar",  { bg = "#252525" })
  vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "#555555" })
end
apply_transparency()
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_transparency })

-- Disable unused providers to avoid healthcheck warnings
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

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

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

require("lazy").setup({
  -- LSP
  { "williamboman/mason.nvim",           config = true },
  { "williamboman/mason-lspconfig.nvim", opts = { automatic_installation = false } },
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

  -- Telescope
  { "nvim-lua/plenary.nvim" },
  { "nvim-telescope/telescope.nvim",            dependencies = { "nvim-lua/plenary.nvim" } },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },

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
  { "lewis6991/gitsigns.nvim", config = true },
  { "tpope/vim-fugitive" },
  { "sindrets/diffview.nvim",  dependencies = { "nvim-lua/plenary.nvim" } },

  -- Editor tools
  { "windwp/nvim-autopairs" },
  { "smoka7/hop.nvim",        version = "*" },
  { "kylechui/nvim-surround", version = "*" },
  { "stevearc/conform.nvim" },
  { "numToStr/Comment.nvim",  config = true },

  -- Testing (lazy: loaded on first keymap use)
  {
    "nvim-neotest/neotest",
    lazy = true,
    keys = { "<leader>nt", "<leader>nf", "<leader>ns", "<leader>no" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-neotest/neotest-python",
    },
    config = function() require("config.testing") end,
  },

  -- Debugging (lazy: loaded on first keymap use)
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    keys = { "<F5>", "<F10>", "<F11>", "<F12>", "<leader>db", "<leader>dB", "<leader>dr", "<leader>du" },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "jay-babu/mason-nvim-dap.nvim",
    },
    config = function() require("config.dap") end,
  },

  -- Code outline (lazy: loaded on first keymap use)
  {
    "stevearc/aerial.nvim",
    lazy = true,
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

  -- Claude Code
  {
    "coder/claudecode.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = true,
  },
}, {
  rocks = { enabled = false, hererocks = false },
})

require("config.ui")
require("config.editor")
require("config.lsp")
require("config.completion")
require("config.autocmds")

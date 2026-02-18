-- Basics
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.cmdheight = 1
vim.opt.showcmd = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.splitright = true
vim.opt.guicursor = "n-v-c:ver25-blinkon500-blinkoff500,i-ci:ver25-blinkon500-blinkoff500"

-- Keep background transparent to let the terminal compositor show through.
local function apply_transparency()
	local groups = {
		"Normal",
		"NormalFloat",
		"FloatBorder",
		"Pmenu",
		"StatusLine",
		"StatusLineNC",
		"WinSeparator",
		"NvimTreeNormal",
		"NvimTreeNormalNC",
		"TelescopeNormal",
		"TelescopeBorder",
		"TroubleNormal",
	}
	for _, group in ipairs(groups) do
		vim.api.nvim_set_hl(0, group, { bg = "none" })
	end
end
apply_transparency()
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_transparency })

-- Disable unused providers to avoid healthcheck warnings.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git", "clone", "--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lazy").setup({
	{ "williamboman/mason.nvim",           config = true },
	{ "williamboman/mason-lspconfig.nvim", opts = { automatic_installation = false } },
	{ "neovim/nvim-lspconfig" },

	{ "hrsh7th/nvim-cmp" },
	{ "hrsh7th/cmp-nvim-lsp" },
	{ "hrsh7th/cmp-buffer" },
	{ "hrsh7th/cmp-path" },
	{ "L3MON4D3/LuaSnip" },
	{ "saadparwaiz1/cmp_luasnip" },

	{ "nvim-treesitter/nvim-treesitter",   build = ":TSUpdate" },

	{ "nvim-lua/plenary.nvim" },
	{ "nvim-telescope/telescope.nvim",     dependencies = { "nvim-lua/plenary.nvim" } },

  {
    "slugbyte/lackluster.nvim",
    priority = 1000,
    config = function()
      local ok_theme, lackluster = pcall(require, "lackluster")
      if ok_theme then
        lackluster.setup({
          tweak_color = {
            black = "#1a1a1a",
            gray1 = "#202020",
            gray2 = "#2a2a2a",
            gray3 = "#333333",
          },
        })
      end
      vim.cmd("colorscheme lackluster")
    end,
  },
	{ "nvim-tree/nvim-tree.lua" },
	{ "tpope/vim-fugitive" },
	{ "vim-test/vim-test" },
	{ "lewis6991/gitsigns.nvim",   config = true },
	{ "folke/trouble.nvim",        dependencies = { "nvim-tree/nvim-web-devicons" }, config = true },
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "windwp/nvim-autopairs" },
  { "smoka7/hop.nvim", version = "*" },
  { "kylechui/nvim-surround", version = "*" },
  { "folke/which-key.nvim" },
	{ "stevearc/conform.nvim" },
	{ "nvimdev/lspsaga.nvim",      dependencies = { "nvim-tree/nvim-web-devicons" } },
	{
		"folke/noice.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
	},
	{
		"coder/claudecode.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = true,
	},
}, {
	rocks = { enabled = false, hererocks = false },
})

require("ide")

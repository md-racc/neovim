-- Claude Code
local ok_claude, claudecode = pcall(require, "claudecode")
if ok_claude then
	claudecode.setup()
	vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude Code" })
	vim.keymap.set("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
end

-- Treesitter
local ok_ts, ts_configs = pcall(require, "nvim-treesitter.configs")
if ok_ts then
	ts_configs.setup({
		highlight = { enable = true },
		indent = { enable = true },
	})
end

-- Telescope
local ok_tel, telescope_builtin = pcall(require, "telescope.builtin")
if ok_tel then
	vim.keymap.set("n", "<leader>ff", telescope_builtin.find_files)
	vim.keymap.set("n", "<leader>fg", telescope_builtin.live_grep)
	vim.keymap.set("n", "<leader>fb", telescope_builtin.buffers)
	vim.keymap.set("n", "<leader>fh", telescope_builtin.help_tags)
end

-- Clear search highlight with double Esc.
vim.keymap.set("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { silent = true })

-- Terminal: open in a vertical split and start in insert mode.
vim.keymap.set("n", "<leader>t", "<cmd>rightbelow vsp | terminal<CR>", { silent = true })
vim.api.nvim_create_autocmd("TermOpen", {
	callback = function()
		vim.cmd("startinsert")
	end,
})

-- Clipboard copy (uses system clipboard)
vim.keymap.set("v", "<leader>y", '"+y', { silent = true })
vim.keymap.set("n", "<leader>yy", '"+yy', { silent = true })

-- Delete without overwriting clipboard
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>dd", '"_dd', { silent = true })

-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })

-- Nvim-tree
local ok_tree, nvim_tree = pcall(require, "nvim-tree")
if ok_tree then
	nvim_tree.setup({
		on_attach = function(bufnr)
			local api = require("nvim-tree.api")
			api.config.mappings.default_on_attach(bufnr)
			local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
			vim.keymap.set("n", "v", api.node.open.vertical, opts)
			vim.keymap.set("n", "s", api.node.open.horizontal, opts)
			vim.keymap.set("n", "t", api.node.open.tab, opts)
		end,
	})
	vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>")
	vim.api.nvim_create_autocmd("VimEnter", {
		callback = function()
			require("nvim-tree.api").tree.open()
			local argc = vim.fn.argc()
			if argc == 0 then
				-- Keep focus on the tree when starting without files.
				return
			end

			if argc == 1 then
				local arg0 = vim.fn.argv(0)
				if vim.fn.isdirectory(arg0) == 1 then
					-- Keep focus on the tree when starting in a directory.
					return
				end
			end

			-- When starting with a file, keep focus on the editing window.
			vim.cmd("wincmd p")
		end,
	})
end

-- Lualine
local ok_ll, lualine = pcall(require, "lualine")
if ok_ll then
	lualine.setup({
		options = {
			globalstatus = true,
			section_separators = { left = "|", right = "|" },
			component_separators = { left = "|", right = "|" },
		},
	})
end

-- Which-key
local ok_wk, which_key = pcall(require, "which-key")
if ok_wk then
	which_key.setup()
end

-- Noice + Notify
local ok_notify, notify = pcall(require, "notify")
if ok_notify then
	notify.setup({ background_colour = "#000000" })
	vim.notify = notify
end

local ok_noice, noice = pcall(require, "noice")
if ok_noice then
	noice.setup({
		cmdline = { enabled = false },
		messages = { enabled = false },
		lsp = {
			signature = { enabled = false },
		},
	})
end

-- Lspsaga
local ok_saga, lspsaga = pcall(require, "lspsaga")
if ok_saga then
  lspsaga.setup({
    lightbulb = { enable = false },
  })
end

-- Conform (formatters)
local ok_conform, conform = pcall(require, "conform")
if ok_conform then
  conform.setup({
    formatters_by_ft = {
      python = { "isort", "black" },
    },
  })
  vim.keymap.set("n", "<leader>F", function()
    conform.format({ lsp_fallback = true })
  end)
end

-- Hop
local ok_hop, hop = pcall(require, "hop")
if ok_hop then
  hop.setup()
  vim.keymap.set("n", "<leader>fw", "<cmd>HopWord<cr>")
  vim.keymap.set("n", "<leader>fl", "<cmd>HopLine<cr>")
end

-- Surround
local ok_surround, surround = pcall(require, "nvim-surround")
if ok_surround then
  surround.setup()
end

-- Completion (nvim-cmp + LuaSnip)
local ok_cmp, cmp = pcall(require, "cmp")
local ok_snip, luasnip = pcall(require, "luasnip")
if ok_cmp and ok_snip then
	cmp.setup({
		completion = {
			autocomplete = { cmp.TriggerEvent.TextChanged },
			keyword_length = 3,
		},
		snippet = {
			expand = function(args)
				luasnip.lsp_expand(args.body)
			end,
		},
		window = {
			completion = {
				max_height = 3,
			},
			documentation = cmp.config.disable,
		},
		mapping = cmp.mapping.preset.insert({
			["<C-Space>"] = cmp.mapping.complete(),
			["<CR>"] = cmp.mapping.confirm({ select = true }),
			["<Tab>"] = cmp.mapping(function(fallback)
				if cmp.visible() then
					cmp.select_next_item()
				elseif luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				else
					fallback()
				end
			end, { "i", "s" }),
			["<S-Tab>"] = cmp.mapping(function(fallback)
				if cmp.visible() then
					cmp.select_prev_item()
				elseif luasnip.jumpable(-1) then
					luasnip.jump(-1)
				else
					fallback()
				end
			end, { "i", "s" }),
		}),
		sources = cmp.config.sources({
			{ name = "nvim_lsp" },
			{ name = "luasnip" },
			{ name = "buffer" },
			{ name = "path" },
		}),
	})
end

-- Keep signature help off and show hover only after CursorHold.
vim.lsp.handlers["textDocument/signatureHelp"] = function() end
vim.opt.updatetime = 1500
do
	local last_pos = { bufnr = nil, line = nil, col = nil }
	local group = vim.api.nvim_create_augroup("DelayedLspHover", { clear = true })

	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		callback = function()
			last_pos.bufnr = nil
		end,
	})

	vim.api.nvim_create_autocmd("CursorHold", {
		group = group,
		callback = function()
			if vim.api.nvim_get_mode().mode ~= "n" then
				return
			end
			local bufnr = vim.api.nvim_get_current_buf()
			local pos = vim.api.nvim_win_get_cursor(0)
			local line, col = pos[1], pos[2]
			if last_pos.bufnr == bufnr and last_pos.line == line and last_pos.col == col then
				return
			end
			last_pos.bufnr, last_pos.line, last_pos.col = bufnr, line, col
			vim.lsp.buf.hover()
		end,
	})
end

-- Autopairs
local ok_pairs, npairs = pcall(require, "nvim-autopairs")
if ok_pairs and not vim.g._nvim_autopairs_setup then
	vim.g._nvim_autopairs_setup = true
	npairs.setup({
		check_ts = true,
		enable_moveright = true,
		map_cr = true,
		map_bs = true,
	})
	local closers = {
		[")"] = true,
		["]"] = true,
		["}"] = true,
		['"'] = true,
		["'"] = true,
	}
	vim.keymap.set("i", "<C-l>", function()
		local line = vim.api.nvim_get_current_line()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local next_char = line:sub(col + 1, col + 1)
		if closers[next_char] then
			return "<Right>"
		end
		return "<C-l>"
	end, { expr = true, noremap = true, silent = true })
end

-- Mason + LSP
local ok_mason, mason = pcall(require, "mason")
if not ok_mason then
	return
end

mason.setup()

-- Capabilities (cmp)
local capabilities = nil
do
	local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
	if ok_cmp then
		capabilities = cmp_nvim_lsp.default_capabilities()
	end
end

-- Servers (Nvim 0.11+ LSP config API)
vim.lsp.config("pyright", { capabilities = capabilities })
vim.lsp.config("clangd", { capabilities = capabilities })
vim.lsp.config("bashls", { capabilities = capabilities })
vim.lsp.config("lua_ls", {
	capabilities = capabilities,
	settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})
vim.lsp.enable({ "pyright", "clangd", "bashls", "lua_ls" })

-- Keymaps
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local opts = { buffer = args.buf }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
		vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, opts)
	end,
})

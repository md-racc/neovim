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

-- Indent blankline
local ok_ibl, ibl = pcall(require, "ibl")
if ok_ibl then
  ibl.setup({ indent = { char = "│" }, scope = { enabled = true } })
end

-- Telescope
local ok_tel, telescope_builtin = pcall(require, "telescope.builtin")
if ok_tel then
  local ok_scope, telescope = pcall(require, "telescope")
  if ok_scope then
    telescope.setup({
      defaults = {
        file_ignore_patterns = {
          "%.git/",
          "node_modules/",
          "__pycache__/",
          "%.pyc",
          "%.pyo",
          "%.venv/",
          "venv/",
          "dist/",
          "build/",
          "%.o",
          "%.a",
          "%.so",
          "lazy%-lock%.json",
        },
        vimgrep_arguments = {
          "rg", "--color=never", "--no-heading", "--with-filename",
          "--line-number", "--column", "--smart-case",
          "--glob=!.git/",
          "--glob=!node_modules/",
          "--glob=!__pycache__/",
          "--glob=!.venv/",
          "--glob=!venv/",
          "--glob=!dist/",
          "--glob=!build/",
        },
      },
    })
    pcall(telescope.load_extension, "fzf")
  end
  vim.keymap.set("n", "<leader>ff", telescope_builtin.find_files)
  vim.keymap.set("n", "<leader>fg", telescope_builtin.live_grep)
  vim.keymap.set("n", "<leader>fb", telescope_builtin.buffers)
  vim.keymap.set("n", "<leader>fh", telescope_builtin.help_tags)
end

-- Clear search highlight with double Esc.
vim.keymap.set("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { silent = true })

-- Exit terminal mode with Esc.
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

-- Terminal: open in a vertical split and start in insert mode.
vim.keymap.set("n", "<leader>t", "<cmd>rightbelow vsp | terminal<CR>", { silent = true })
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})
-- Re-enter terminal mode when focusing a terminal window (so Emacs bindings work on return)
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "term://*",
  callback = function() vim.cmd("startinsert") end,
})

-- Clipboard copy/paste (Wayland: requires wl-clipboard)
vim.keymap.set("v", "<leader>y",  '"+y',  { silent = true, desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>yy", '"+yy', { silent = true, desc = "Yank line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { silent = true, desc = "Paste from system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>P", '"+P', { silent = true, desc = "Paste before from system clipboard" })

-- Delete without overwriting clipboard
vim.keymap.set({ "n", "v" }, "<leader>d", '"_d', { silent = true })
vim.keymap.set("n", "<leader>dd", '"_dd', { silent = true })

-- Window navigation
vim.keymap.set("n", "<C-w>", "<Nop>", { silent = true })
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })

-- Split creation
vim.keymap.set("n", "<leader>sv", "<cmd>vsplit<cr>", { silent = true, desc = "Vertical split" })
vim.keymap.set("n", "<leader>sh", "<cmd>split<cr>",  { silent = true, desc = "Horizontal split" })

-- Window resize
vim.keymap.set("n", "<C-Up>",    "<cmd>resize +2<cr>",          { silent = true, desc = "Increase height" })
vim.keymap.set("n", "<C-Down>",  "<cmd>resize -2<cr>",          { silent = true, desc = "Decrease height" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { silent = true, desc = "Increase width" })
vim.keymap.set("n", "<C-Left>",  "<cmd>vertical resize -2<cr>", { silent = true, desc = "Decrease width" })

-- Diffview
local ok_dv, _ = pcall(require, "diffview")
if ok_dv then
  vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>",            { desc = "Diff working tree" })
  vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",   { desc = "File git history" })
  vim.keymap.set("n", "<leader>gH", "<cmd>DiffviewFileHistory<cr>",     { desc = "Repo git history" })
  vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",           { desc = "Close diffview" })
end

-- Trouble + diagnostics
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              { desc = "Workspace diagnostics" })
vim.keymap.set("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })

-- Aerial (code outline)
local ok_aerial, aerial = pcall(require, "aerial")
if ok_aerial then
  aerial.setup({ attach_mode = "cursor", layout = { default_direction = "right" } })
  vim.keymap.set("n", "<leader>o", "<cmd>AerialToggle<cr>", { desc = "Toggle code outline" })
end

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

			if argc == 1 then
				local arg0 = vim.fn.argv(0)
				if vim.fn.isdirectory(arg0) == 1 then
					-- Directory: pop telescope scoped to it, tree stays on side
					vim.schedule(function()
						require("telescope.builtin").find_files({ cwd = arg0 })
					end)
					return
				end
				-- File: focus the editing window, tree stays on side
				vim.cmd("wincmd p")
				return
			end

			-- No args: pop telescope in cwd, tree stays on side
			vim.schedule(function()
				require("telescope.builtin").find_files()
			end)
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

-- Bufferline
local ok_bl, bufferline = pcall(require, "bufferline")
if ok_bl then
  bufferline.setup({
    options = {
      offsets = { { filetype = "NvimTree", text = "Files", highlight = "Directory" } },
    },
  })
  vim.keymap.set("n", "<Tab>",      "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
  vim.keymap.set("n", "<S-Tab>",    "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
  vim.keymap.set("n", "<leader>br", "<cmd>BufferLineMoveNext<cr>",  { desc = "Move buffer right" })
  vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineMovePrev<cr>",  { desc = "Move buffer left" })
  vim.keymap.set("n", "<leader>bc", "<cmd>bdelete<cr>",             { desc = "Close buffer" })
  for i = 1, 9 do
    vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<cr>", { desc = "Go to buffer " .. i })
  end
end

-- Which-key
local ok_wk, which_key = pcall(require, "which-key")
if ok_wk then
	which_key.setup()
end

-- Noice
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

-- Conform (formatters)
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
      sh              = { "shfmt" },
      bash            = { "shfmt" },
      c               = { "clang_format" },
      cpp             = { "clang_format" },
    },
  })
  vim.keymap.set("n", "<leader>F", function()
    conform.format({ lsp_fallback = true })
  end)
end

-- Neotest
local ok_neotest, neotest = pcall(require, "neotest")
if ok_neotest then
	local ok_neotest_python, neotest_python = pcall(require, "neotest-python")
	local adapters = {}
	if ok_neotest_python then
		table.insert(adapters, neotest_python)
	end
	neotest.setup({
		adapters = adapters,
	})
	vim.keymap.set("n", "<leader>nt", function() neotest.run.run() end, { desc = "Run nearest test" })
	vim.keymap.set("n", "<leader>nf", function() neotest.run.run(vim.fn.expand("%")) end, { desc = "Run test file" })
	vim.keymap.set("n", "<leader>ns", function() neotest.summary.toggle() end, { desc = "Toggle test summary" })
	vim.keymap.set("n", "<leader>no", function() neotest.output_panel.toggle() end, { desc = "Toggle test output" })
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
			local has_hover_client = false
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
				if client:supports_method("textDocument/hover") then
					has_hover_client = true
					break
				end
			end
			if not has_hover_client then
				return
			end
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

-- DAP
local ok_dap, dap = pcall(require, "dap")
local ok_dapui, dapui = pcall(require, "dapui")
if ok_dap and ok_dapui then
	dapui.setup()
	dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
	dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
	dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

	vim.keymap.set("n", "<F5>",  dap.continue,    { desc = "Debug: continue" })
	vim.keymap.set("n", "<F10>", dap.step_over,   { desc = "Debug: step over" })
	vim.keymap.set("n", "<F11>", dap.step_into,   { desc = "Debug: step into" })
	vim.keymap.set("n", "<F12>", dap.step_out,    { desc = "Debug: step out" })
	vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
	vim.keymap.set("n", "<leader>dB", function()
		dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
	end, { desc = "Conditional breakpoint" })
	vim.keymap.set("n", "<leader>dr", dap.repl.open,  { desc = "Open DAP REPL" })
	vim.keymap.set("n", "<leader>du", dapui.toggle,   { desc = "Toggle DAP UI" })
end

local ok_masondap, mason_dap = pcall(require, "mason-nvim-dap")
if ok_masondap then
	mason_dap.setup({
		ensure_installed = { "python" },
		automatic_installation = true,
		handlers = {},
	})
end

-- Mason + LSP
local ok_mason, mason = pcall(require, "mason")
if ok_mason then
	mason.setup()
end

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
	end,
})

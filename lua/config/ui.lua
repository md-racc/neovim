-- Treesitter: syntax highlighting, indentation, and auto-install parsers
local ok_ts, ts_configs = pcall(require, "nvim-treesitter.configs")
if ok_ts then
  ts_configs.setup({
    ensure_installed = {
      "python", "cpp", "c", "lua", "bash",
      "latex", "markdown", "markdown_inline",
    },
    auto_install = true,
    highlight    = { enable = true },
    indent       = { enable = true },
  })
end

-- Indent blankline
local ok_ibl, ibl = pcall(require, "ibl")
if ok_ibl then
  ibl.setup({ indent = { char = "│" }, scope = { enabled = true } })
end

-- Render-markdown (in-buffer rendering)
local ok_rmd, render_markdown = pcall(require, "render-markdown")
if ok_rmd then
  render_markdown.setup({})
end

-- Telescope
local ok_tel, telescope_builtin = pcall(require, "telescope.builtin")
if ok_tel then
  local ok_scope, telescope = pcall(require, "telescope")
  if ok_scope then
    telescope.setup({
      defaults = {
        file_ignore_patterns = {
          "%.git/", "node_modules/", "__pycache__/", "%.pyc", "%.pyo",
          "%.venv/", "venv/", "dist/", "build/", "%.o", "%.a", "%.so",
          "lazy%-lock%.json",
        },
        vimgrep_arguments = {
          "rg", "--color=never", "--no-heading", "--with-filename",
          "--line-number", "--column", "--smart-case",
          "--glob=!.git/", "--glob=!node_modules/", "--glob=!__pycache__/",
          "--glob=!.venv/", "--glob=!venv/", "--glob=!dist/", "--glob=!build/",
        },
      },
    })
    pcall(telescope.load_extension, "fzf")
  end
  vim.keymap.set("n", "<leader>ff", telescope_builtin.find_files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fg", telescope_builtin.live_grep,  { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fb", telescope_builtin.buffers,    { desc = "Buffers" })
  vim.keymap.set("n", "<leader>fh", telescope_builtin.help_tags,  { desc = "Help tags" })
end

-- Nvim-tree
local ok_tree, nvim_tree = pcall(require, "nvim-tree")
if ok_tree then
  nvim_tree.setup({
    on_attach = function(bufnr)
      local api = require("nvim-tree.api")
      api.config.mappings.default_on_attach(bufnr)
      local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
      vim.keymap.set("n", "v", api.node.open.vertical,   opts)
      vim.keymap.set("n", "s", api.node.open.horizontal, opts)
      vim.keymap.set("n", "t", api.node.open.tab,        opts)
    end,
  })
  vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      require("nvim-tree.api").tree.open()
      local argc = vim.fn.argc()
      if argc == 1 then
        local arg0 = vim.fn.argv(0)
        if vim.fn.isdirectory(arg0) == 1 then
          vim.schedule(function()
            require("telescope.builtin").find_files({ cwd = arg0 })
          end)
          return
        end
        vim.cmd("wincmd p")
        return
      end
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
      globalstatus        = true,
      section_separators   = { left = "|", right = "|" },
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
    vim.keymap.set("n", "<leader>" .. i,
      "<cmd>BufferLineGoToBuffer " .. i .. "<cr>",
      { desc = "Go to buffer " .. i })
  end
end

-- Which-key
local ok_wk, which_key = pcall(require, "which-key")
if ok_wk then
  which_key.setup()
  which_key.add({
    { "<leader>a", group = "AI" },
    { "<leader>b", group = "buffers" },
    { "<leader>d", group = "debug" },
    { "<leader>f", group = "find / hop" },
    { "<leader>g", group = "git" },
    { "<leader>n", group = "test" },
    { "<leader>o", group = "outline" },
    { "<leader>r", group = "refactor" },
    { "<leader>s", group = "splits" },
    { "<leader>x", group = "diagnostics" },
    { "<leader>y", group = "yank" },
  })
end

-- Hop (motion)
local ok_hop, hop = pcall(require, "hop")
if ok_hop then
  hop.setup()
  vim.keymap.set("n", "<leader>fw", "<cmd>HopWord<cr>", { desc = "Hop to word" })
  vim.keymap.set("n", "<leader>fl", "<cmd>HopLine<cr>", { desc = "Hop to line" })
end

-- Surround
local ok_surround, surround = pcall(require, "nvim-surround")
if ok_surround then
  surround.setup()
end

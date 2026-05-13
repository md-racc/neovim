-- Capabilities (enhanced by cmp-nvim-lsp)
local capabilities = nil
do
  local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end
end

-- Server configuration (Neovim 0.11+ LSP API)
vim.lsp.config("pyright", { capabilities = capabilities })
vim.lsp.config("clangd",  { capabilities = capabilities })
vim.lsp.config("bashls",  { capabilities = capabilities })
vim.lsp.config("lua_ls",  {
  capabilities = capabilities,
  settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})
vim.lsp.enable({ "pyright", "clangd", "bashls", "lua_ls" })

-- Disable signature help popup; show hover after cursor is still instead
vim.lsp.handlers["textDocument/signatureHelp"] = function() end
vim.opt.updatetime = 1500

do
  local last_pos = { bufnr = nil, line = nil, col = nil }
  local group = vim.api.nvim_create_augroup("DelayedLspHover", { clear = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group    = group,
    callback = function() last_pos.bufnr = nil end,
  })

  vim.api.nvim_create_autocmd("CursorHold", {
    group    = group,
    callback = function()
      if vim.api.nvim_get_mode().mode ~= "n" then return end
      local bufnr     = vim.api.nvim_get_current_buf()
      local has_hover = false
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if client:supports_method("textDocument/hover") then
          has_hover = true
          break
        end
      end
      if not has_hover then return end
      local pos       = vim.api.nvim_win_get_cursor(0)
      local line, col = pos[1], pos[2]
      if last_pos.bufnr == bufnr and last_pos.line == line and last_pos.col == col then
        return
      end
      last_pos.bufnr, last_pos.line, last_pos.col = bufnr, line, col
      vim.lsp.buf.hover()
    end,
  })
end

-- Mason
local ok_mason, mason = pcall(require, "mason")
if ok_mason then
  mason.setup()
end

-- LSP keymaps (set per-buffer on attach)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local o    = function(desc) return vim.tbl_extend("force", opts, { desc = desc }) end
    vim.keymap.set("n", "gd",         vim.lsp.buf.definition,  o("Go to definition"))
    vim.keymap.set("n", "gr",         vim.lsp.buf.references,  o("References"))
    vim.keymap.set("n", "K",          vim.lsp.buf.hover,       o("Hover docs"))
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,      o("Rename symbol"))
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, o("Code actions"))
  end,
})

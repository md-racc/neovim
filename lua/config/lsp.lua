-- =============================================================================
-- CAPABILITIES
-- =============================================================================

local capabilities = nil
do
  local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if ok_cmp then
    capabilities = cmp_nvim_lsp.default_capabilities()
  end
end

-- =============================================================================
-- SERVERS
-- =============================================================================

vim.lsp.config("pyright", { capabilities = capabilities })
vim.lsp.config("clangd",  { capabilities = capabilities })
vim.lsp.config("bashls",  { capabilities = capabilities })
vim.lsp.config("lua_ls",  {
  capabilities = capabilities,
  settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})
vim.lsp.enable({ "pyright", "clangd", "bashls", "lua_ls" })

-- =============================================================================
-- HOVER
-- =============================================================================

-- Disable signature help popup
vim.lsp.handlers["textDocument/signatureHelp"] = function() end

-- Hover is manual only: press K on a symbol (see keymaps below).

-- =============================================================================
-- KEYMAPS
-- =============================================================================

-- Set keymaps per-buffer on LSP attach
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local o    = function(desc) return vim.tbl_extend("force", opts, { desc = desc }) end
    vim.keymap.set("n", "gd",         vim.lsp.buf.definition,  o("Go to definition"))
    vim.keymap.set("n", "gr",         vim.lsp.buf.references,  o("References"))
    vim.keymap.set("n", "K", function()
      vim.lsp.buf.hover({ focusable = false, border = "none" })
    end, o("Hover docs"))
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,      o("Rename symbol"))
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, o("Code actions"))

    -- clangd-only: inlay hints and header/source toggle
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "clangd" then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      vim.keymap.set("n", "<leader>ci", function()
        vim.lsp.inlay_hint.enable(
          not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }),
          { bufnr = args.buf }
        )
      end, o("Toggle inlay hints"))
      vim.keymap.set("n", "<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", o("Switch header/source"))
    end
  end,
})

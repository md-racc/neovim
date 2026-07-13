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

-- Python: prefer basedpyright (drop-in pyright fork with reliable call
-- hierarchy + better inference); fall back to pyright if it isn't installed.
local py_server = vim.fn.executable("basedpyright") == 1 and "basedpyright" or "pyright"
vim.lsp.config(py_server, { capabilities = capabilities })

vim.lsp.config("clangd",  {
  capabilities = capabilities,
  -- Out-of-line definition completion: in a .cpp, type `Class::`, pick the
  -- method, and clangd inserts the full `Ret Class::method(args) { $0 }` with
  -- the cursor placed in the body. Needs snippetSupport (from cmp_nvim_lsp).
  cmd = {
    "clangd",
    "--function-arg-placeholders", -- args become fillable tab-stops
    "--completion-style=detailed",
  },
})
vim.lsp.config("bashls",  { capabilities = capabilities })
vim.lsp.config("lua_ls",  {
  capabilities = capabilities,
  settings = { Lua = { diagnostics = { globals = { "vim" } } } },
})
vim.lsp.enable({ py_server, "clangd", "bashls", "lua_ls" })

-- =============================================================================
-- HOVER
-- =============================================================================

-- Disable signature help popup
vim.lsp.handlers["textDocument/signatureHelp"] = function() end

-- Hover is manual only: press K on a symbol (see keymaps below).

-- =============================================================================
-- KEYMAPS — the +Code (<leader>c) namespace, language-agnostic.
-- =============================================================================
-- Language-specific verbs (call hierarchy, header/source switch, run/build)
-- live in the buffer-local language modules under lua/lang/ instead.

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf }
    local o    = function(desc) return vim.tbl_extend("force", opts, { desc = desc }) end
    local ok_fzf, fzf = pcall(require, "fzf-lua")

    -- Bare-key LSP navigation (kept as Vim-ish reflexes).
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, o("Go to definition"))
    vim.keymap.set("n", "gr", vim.lsp.buf.references, o("References"))
    vim.keymap.set("n", "K", function()
      vim.lsp.buf.hover({ focusable = false, border = "none" })
    end, o("Hover docs"))

    -- +Code
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, o("Code action"))
    vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename,      o("Rename symbol"))
    vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run,    o("Run codelens"))
    vim.keymap.set("n", "<leader>cx", "<cmd>LspRestart<cr>",   o("Restart LSP"))
    vim.keymap.set("n", "<leader>cI", "<cmd>LspInfo<cr>",      o("LSP info"))
    -- Symbols: Shift = wider scope (document -> workspace).
    if ok_fzf then
      vim.keymap.set("n", "<leader>cs", fzf.lsp_document_symbols,        o("Document symbols"))
      vim.keymap.set("n", "<leader>cS", fzf.lsp_live_workspace_symbols,  o("Workspace symbols"))
    else
      vim.keymap.set("n", "<leader>cs", vim.lsp.buf.document_symbol,     o("Document symbols"))
      vim.keymap.set("n", "<leader>cS", vim.lsp.buf.workspace_symbol,    o("Workspace symbols"))
    end

    -- clangd advertises inlay hints and we enable them by default there; the
    -- generic on/off toggle lives at <leader>ui (see lua/config/toggles.lua).
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "clangd" then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
    end

    -- Refresh codelens for clients that support it so <leader>cl has something
    -- to run.
    if client and client:supports_method("textDocument/codeLens") then
      vim.lsp.codelens.refresh({ bufnr = args.buf })
      vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
        buffer = args.buf,
        callback = function() pcall(vim.lsp.codelens.refresh, { bufnr = args.buf }) end,
      })
    end
  end,
})

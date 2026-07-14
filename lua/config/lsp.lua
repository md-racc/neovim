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
  --
  -- `cmd` is a function so the clangd binary + args can vary per project root:
  -- esp-clang for Xtensa, --query-driver for arm-none-eabi, --compile-commands-dir
  -- for the cross-compiled build (see lua/lang/embedded.lua). For a HOST C++
  -- project (embedded.detect -> nil) the argv is byte-identical to the previous
  -- static list, and the spawn params mirror Neovim's own default cmd spawn, so
  -- there is no regression on the plain g++/clangd path (acceptance #2).
  cmd = function(dispatchers, config)
    local ok, embedded = pcall(require, "lang.embedded")
    local argv = ok and embedded.clangd_argv(config and config.root_dir)
      or { "clangd", "--function-arg-placeholders", "--completion-style=detailed" }
    return vim.lsp.rpc.start(argv, dispatchers, {
      cwd      = config.cmd_cwd,
      env      = config.cmd_env,
      detached = config.detached,
    })
  end,
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

-- Restart every LSP client on the current buffer, then re-attach by re-firing
-- FileType (vim.lsp.enable auto-starts servers on that event). Non-destructive:
-- no buffer reload, so unsaved changes are untouched.
local function restart_lsp()
  local buf     = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf })
  if #clients == 0 then
    vim.notify("No LSP client attached", vim.log.levels.WARN)
    return
  end
  local names = vim.tbl_map(function(c) return c.name end, clients)
  for _, c in ipairs(clients) do c:stop(true) end
  vim.notify("Restarting LSP: " .. table.concat(names, ", "))
  -- Poll until the clients have actually exited, then re-trigger attach.
  local tries, timer = 0, assert(vim.uv.new_timer())
  timer:start(100, 100, vim.schedule_wrap(function()
    tries = tries + 1
    if #vim.lsp.get_clients({ bufnr = buf }) == 0 or tries > 30 then
      timer:stop(); timer:close()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_call(buf, function()
          vim.api.nvim_exec_autocmds("FileType", { modeline = false })
        end)
      end
    end
  end))
end

-- =============================================================================
-- PROGRESS -> dunst
-- =============================================================================
-- LSP server messages (window/showMessage, "No X found", errors) already flow
-- through vim.notify, which lua/config/notify.lua routes to dunst. Progress does
-- not — so route it too, but only the begin/end of each task (pattern filter),
-- coalesced into one self-replacing popup per client (stack tag = client name in
-- notify.lua) at low urgency. The high-frequency "report" updates are ignored so
-- we never spawn a notify-send per tick.
vim.api.nvim_create_autocmd("LspProgress", {
  pattern  = { "begin", "end" },
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local value  = ev.data.params and ev.data.params.value
    if not client or type(value) ~= "table" then return end
    local title = value.title or "LSP"
    local msg
    if value.kind == "end" then
      msg = title .. " — done"
    else
      msg = value.message and (title .. ": " .. value.message) or title
    end
    vim.notify(msg, vim.log.levels.INFO, { title = client.name })
  end,
})

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
    -- Native restart / info: this config drives LSP via vim.lsp.config +
    -- vim.lsp.enable (no lspconfig setup), so :LspRestart/:LspInfo don't exist.
    vim.keymap.set("n", "<leader>cx", restart_lsp,             o("Restart LSP"))
    vim.keymap.set("n", "<leader>cI", "<cmd>checkhealth vim.lsp<cr>", o("LSP info"))
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

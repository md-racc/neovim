-- =============================================================================
-- COMPLETION
-- =============================================================================

local ok_cmp,  cmp     = pcall(require, "cmp")
local ok_snip, luasnip = pcall(require, "luasnip")
local ok_np,   npairs  = pcall(require, "nvim-autopairs")

if ok_cmp and ok_snip then
  cmp.setup({
    completion = {
      autocomplete   = { cmp.TriggerEvent.TextChanged },
      -- 1, not 3: at 3 the menu stayed closed after `Class::` (the member name
      -- typed is usually < 3 chars), which defeated out-of-line definition
      -- completion and forced a manual <C-Space>. Trigger characters (`.`, `->`,
      -- `::` for clangd) are advertised by the server and honoured by cmp
      -- regardless of keyword_length, so `Class::` now pops the member list on
      -- its own.
      keyword_length = 1,
      -- noinsert: highlighting an item while scrolling does NOT drop its text
      -- into the buffer; nothing is inserted until you confirm (<CR>/<C-y>).
      completeopt    = "menu,menuone,noinsert,noselect",
    },
    snippet = {
      expand = function(args) luasnip.lsp_expand(args.body) end,
    },
    window = {
      completion    = { max_height = 3 },
      documentation = cmp.config.disable,
    },
    mapping = cmp.mapping.preset.insert({
      ["<C-Space>"] = cmp.mapping.complete(),
      -- Menu open -> confirm the (first) item. Menu closed -> hand <CR> to
      -- nvim-autopairs so `{` + <CR> still expands into an indented block.
      -- (autopairs is set up with map_cr=false so cmp can own <CR>, which means
      -- its own <CR> handler is otherwise never reached — we call it here.)
      ["<CR>"] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.confirm({ select = true })
        elseif ok_np then
          vim.api.nvim_feedkeys(npairs.autopairs_cr(), "n", false)
        else
          fallback()
        end
      end, { "i" }),
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

  -- Since autopairs no longer maps <CR> (cmp owns it), re-add auto-parens after
  -- confirming a function/method completion via cmp's confirm_done event.
  local ok_ap, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
  if ok_ap then
    -- Disable auto-parens for c/cpp: clangd's --function-arg-placeholders
    -- already sends call completions as a snippet *with* parens, and for
    -- out-of-line definitions the stub hook below manages the signature — so
    -- autopairs adding `()` here is redundant and races with that hook.
    cmp.event:on("confirm_done",
      cmp_autopairs.on_confirm_done({ filetypes = { c = false, cpp = false } }))
  end

  -- ---------------------------------------------------------------------------
  -- C/C++: expand an out-of-line definition into a full stub on confirm.
  --
  -- When you type `Class::method` in a .cpp, clangd's completion only ever
  -- inserts the bare method name (verified: insertTextFormat = PlainText, no
  -- signature, no body) — it never sends the stub. But the completion item
  -- still carries the pieces we need: `labelDetails.detail` has the parameter
  -- list and `detail` has the return type. This hook reconstructs
  --     Ret Class::method(params) {
  --         <cursor>
  --     }
  -- (attach brace style, matching clang-format's LLVM default so a save-time
  -- reformat is a no-op) and drops the cursor in the body. Runs via
  -- vim.schedule so it settles
  -- *after* autopairs' own confirm_done handler (which may have appended `()`).
  local DEF_KIND = { [2] = true, [3] = true, [4] = true } -- Method, Function, Constructor

  -- True when the cursor sits inside a function body (`{ ... }`) — there a
  -- `Class::name` completion is a *call*, not a definition, so we leave it be.
  -- Out-of-line definitions live at file/namespace scope (no compound_statement
  -- ancestor). Best-effort: if treesitter can't tell, we allow the rewrite.
  local function inside_function_body()
    local ok, node = pcall(vim.treesitter.get_node)
    if not ok or not node then return false end
    while node do
      if node:type() == "compound_statement" then return true end
      node = node:parent()
    end
    return false
  end

  cmp.event:on("confirm_done", function(evt)
    local entry = evt and evt.entry
    if not entry then return end
    if vim.bo.filetype ~= "cpp" and vim.bo.filetype ~= "c" then return end
    if not entry.source or entry.source.name ~= "nvim_lsp" then return end

    local ok_item, item = pcall(function() return entry:get_completion_item() end)
    if not ok_item or type(item) ~= "table" then return end
    if not DEF_KIND[item.kind] then return end
    -- insertTextFormat 2 == Snippet: that's a *call* completion (arg
    -- placeholders), which clangd only sends outside a definition context.
    if item.insertTextFormat == 2 then return end

    -- Parameter list. When the client advertises labelDetailsSupport (which
    -- cmp_nvim_lsp does) clangd puts the params in labelDetails.detail, e.g.
    -- "(int width, int height)", and leaves the label as just the name.
    -- Without that support the params are folded into the label. Handle both.
    local label = type(item.label) == "string" and vim.trim(item.label) or ""
    local ld    = item.labelDetails
    local params
    -- NB: string.find returns (start, end); capture just the start position,
    -- otherwise `sub(find(...))` becomes sub(start, end) and yields one char.
    local ldp = type(ld) == "table" and type(ld.detail) == "string"
      and ld.detail:find("(", 1, true) or nil
    if ldp then
      params = ld.detail:sub(ldp)
    else
      local lp = label:find("(", 1, true)
      if lp then params = label:sub(lp) end
    end
    if not params then return end -- no parameter info -> not function-like

    local name = item.insertText
    if type(name) ~= "string" or name == "" then name = label:gsub("%s*%(.*$", "") end
    name = vim.trim(name)
    if name == "" then return end
    local detail = type(item.detail) == "string" and vim.trim(item.detail) or ""

    local bufnr = vim.api.nvim_get_current_buf()
    local row   = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

    vim.schedule(function()
      if vim.api.nvim_get_current_buf() ~= bufnr then return end
      if inside_function_body() then return end

      local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
      if not line then return end

      -- `::name` is the hallmark of a qualified out-of-line definition. If it's
      -- absent this wasn't that context — leave the completion untouched.
      local qstart, nameend = line:find("::" .. vim.pesc(name), 1, true)
      if not qstart then return end

      local indent = line:match("^%s*") or ""
      local head   = line:sub(1, nameend)     -- indent + [ret type] + Class::name
      local before = line:sub(1, qstart - 1)  -- indent + [ret type] + qualifier

      -- Skip qualified *calls* in an expression context: `x = Foo::bar`,
      -- `return Foo::bar`, `f(Foo::bar)`, `std::cout << Foo::bar`, etc.
      local lead = vim.trim(before)
      if lead:find("[=%(%.]") or lead:find("<<", 1, true)
          or lead:match("^return%f[%W]") then
        return
      end

      -- Return type already typed? Strip the trailing qualifier chain from
      -- `before`; anything left (past the indent) is the return type.
      local without_qual = before:gsub("[%w_][%w_:<>]*%s*$", "")
      local has_rt = vim.trim(without_qual) ~= ""

      -- Signature = the parameter list (+ any trailing const/noexcept). Drop
      -- default values and trailers that are illegal on an out-of-line def.
      local sig = params
      sig = sig:gsub("%s*=%s*[^,)]+", "")      -- default arguments
      sig = sig:gsub("%s*=%s*0%s*$", "")       -- pure virtual
      sig = sig:gsub("%s+override%f[%W].*$", "")
      sig = sig:gsub("%s+final%f[%W].*$", "")

      local first = head .. sig
      if not has_rt and detail ~= "" then
        first = indent .. detail .. " " .. head:sub(#indent + 1) .. sig
      end

      local body_indent = vim.bo.expandtab
        and string.rep(" ", vim.fn.shiftwidth())
        or "\t"
      local body = indent .. body_indent
      -- Attach brace style: `{` on the signature line (matches clang-format).
      vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false,
        { first .. " {", body, indent .. "}" })
      vim.api.nvim_win_set_cursor(0, { row + 1, #body })
    end)
  end)

  -- TeX: add vimtex source for \ref, \cite, \label completion
  cmp.setup.filetype("tex", {
    sources = cmp.config.sources({
      { name = "vimtex" },
      { name = "nvim_lsp" },
      { name = "luasnip" },
      { name = "buffer" },
      { name = "path" },
    }),
  })
end

-- =============================================================================
-- SNIPPETS
-- =============================================================================

-- Load Lua-format snippets from luasnippets/
if ok_snip then
  luasnip.setup({ enable_autosnippets = true })
  require("luasnip.loaders.from_lua").lazy_load({
    paths = { vim.fn.stdpath("config") .. "/luasnippets" },
  })
end

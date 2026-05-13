local ok_cmp,  cmp     = pcall(require, "cmp")
local ok_snip, luasnip = pcall(require, "luasnip")

if ok_cmp and ok_snip then
  cmp.setup({
    completion = {
      autocomplete   = { cmp.TriggerEvent.TextChanged },
      keyword_length = 3,
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
      ["<CR>"]      = cmp.mapping.confirm({ select = true }),
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

  -- TeX-specific: add vimtex source for \ref, \cite, \label completion
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

-- Load Lua-format snippets from luasnippets/
if ok_snip then
  require("luasnip.loaders.from_lua").lazy_load({
    paths = { vim.fn.stdpath("config") .. "/luasnippets" },
  })
end

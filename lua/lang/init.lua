-- =============================================================================
-- LANGUAGE DISPATCHER  (<leader>l — buffer-local, per language)
-- =============================================================================
-- One FileType autocmd. On a match it require()s the matching module (a missing
-- module is not an error), applies its maps buffer-locally, and registers the
-- +language which-key group *for that buffer* so the menu re-labels itself
-- (+C++ in a .cpp, +Python in a .py, nothing where no module matched).
--
-- Buffer-local maps shadow any global <leader>l bind of the same lhs, so the
-- namespace is simply empty in buffers with no language module.
--
-- Adding a language = drop one file in lua/lang/. Nothing else changes.
--
-- Module contract (lua/lang/<name>.lua):
--   return {
--     name   = "Python",                 -- which-key group label (+Python)
--     groups = { { "lm", "CMake" } },    -- optional sub-group labels
--     maps   = {
--       { "lr", fn, desc = "Run file", mode = "n" },  -- lhs is <leader> + m[1]
--     },
--   }

-- Filetype -> module name (several filetypes may share a module).
local MODULE = {
  cpp    = "cpp",
  c      = "cpp",
  python = "python",
  lua    = "lua",
  sh     = "sh",
  bash   = "sh",
}

vim.api.nvim_create_autocmd("FileType", {
  group    = vim.api.nvim_create_augroup("LangModules", { clear = true }),
  callback = function(args)
    local modname = MODULE[args.match]
    if not modname then return end
    local ok, mod = pcall(require, "lang." .. modname)
    if not ok or type(mod) ~= "table" then return end

    local buf = args.buf
    for _, m in ipairs(mod.maps or {}) do
      vim.keymap.set(m.mode or "n", "<leader>" .. m[1], m[2],
        { buffer = buf, desc = m.desc, silent = m.silent })
    end

    local ok_wk, wk = pcall(require, "which-key")
    if ok_wk then
      if mod.name then
        wk.add({ { "<leader>l", group = mod.name, buffer = buf } })
      end
      for _, g in ipairs(mod.groups or {}) do
        wk.add({ { "<leader>" .. g[1], group = g[2], buffer = buf } })
      end
    end
  end,
})

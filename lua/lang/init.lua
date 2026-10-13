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
--     name   = "Python",                 -- group label (+Python)
--     -- optional sub-group labels; icon = a Material Design codepoint baked
--     -- into the mini.clue desc (matches the group glyphs in config/ui.lua)
--     groups = { { "lm", "CMake", icon = 0xF08EA } },
--     maps   = {
--       { "lr", fn, desc = "Run file", mode = "n" },  -- lhs is <leader> + m[1]
--     },
--     -- Optional. A per-buffer predicate: return false to skip registering a
--     -- given map in this buffer. Used by cpp.lua to register the embedded
--     -- <leader>lf* sub-group (and hide lm*) only in detected embedded projects,
--     -- while keeping `maps` a static superset so the docs generator (which
--     -- dofile()s the module and reads `maps`) still lists every bind. A module
--     -- whose maps are the same in every buffer omits this entirely.
--     filter = function(buf, lhs) return true end,
--     -- Optional. Descs for maps a *plugin* creates (lhs minus <leader>), for
--     -- modules that own no maps themselves (tex.lua over vimtex). A label
--     -- whose map doesn't exist in the buffer becomes a hint-only clue.
--     labels = { ll = "Compile" },
--     -- Optional. Per-buffer setup (buffer options, enabling a view); runs
--     -- with `buf` current, after maps and labels are applied.
--     attach = function(buf) end,
--   }

-- Filetype -> module name (several filetypes may share a module).
local MODULE = {
  cpp    = "cpp",
  c      = "cpp",
  python = "python",
  lua    = "lua",
  sh     = "sh",
  bash   = "sh",
  tex    = "tex",
  csv    = "csv",
  tsv    = "csv",
}

vim.api.nvim_create_autocmd("FileType", {
  group    = vim.api.nvim_create_augroup("LangModules", { clear = true }),
  callback = function(args)
    local modname = MODULE[args.match]
    if not modname then return end
    local ok, mod = pcall(require, "lang." .. modname)
    if not ok or type(mod) ~= "table" then return end

    local buf = args.buf
    local registered = {} -- depth-3 prefixes ("lm"/"lf") that got at least one map
    for _, m in ipairs(mod.maps or {}) do
      if not mod.filter or mod.filter(buf, m[1]) then
        vim.keymap.set(m.mode or "n", "<leader>" .. m[1], m[2],
          { buffer = buf, desc = m.desc, silent = m.silent })
        if #m[1] >= 3 then registered[m[1]:sub(1, 2)] = true end
      end
    end

    -- mini.clue (the active leader-hint UI): buffer-local clues are
    -- concatenated after the global ones and a later desc wins, so this both
    -- relabels <leader>l per language (+C++, +Python, ...) and surfaces the
    -- sub-group labels ONLY in buffers where the filter registered maps under
    -- them — no phantom +CMake/+Flash rows in other languages.
    local ic = function(cp) return vim.fn.nr2char(cp) .. " " end
    local clues = {}
    if mod.name then
      clues[#clues + 1] = { mode = "n", keys = "<Leader>l", desc = ic(0xF0174) .. "+" .. mod.name }
    end
    -- Plugin-owned maps: patch the mapping's own desc, since mini.clue prefers
    -- an existing mapping's desc (even an empty one) over a `clues` entry.
    local ok_mc, MiniClue = pcall(require, "mini.clue")
    for lhs, desc in pairs(mod.labels or {}) do
      local key = "<Leader>" .. lhs
      if vim.tbl_isempty(vim.fn.maparg(key, "n", false, true)) or not ok_mc then
        clues[#clues + 1] = { mode = "n", keys = key, desc = desc }
      else
        pcall(MiniClue.set_mapping_desc, "n", key, desc)
      end
    end
    for _, g in ipairs(mod.groups or {}) do
      if registered[g[1]] then
        clues[#clues + 1] = {
          mode = "n",
          keys = "<Leader>" .. g[1],
          desc = (g.icon and ic(g.icon) or "") .. "+" .. g[2],
        }
      end
    end
    vim.b[buf].miniclue_config = { clues = clues }

    -- which-key is DEPRECATED dormant scaffolding (see lua/config/ui.lua);
    -- keep feeding it so a one-line revert still relabels correctly.
    local ok_wk, wk = pcall(require, "which-key")
    if ok_wk then
      if mod.name then
        wk.add({ { "<leader>l", group = mod.name, buffer = buf } })
      end
      for _, g in ipairs(mod.groups or {}) do
        wk.add({ { "<leader>" .. g[1], group = g[2], buffer = buf } })
      end
    end

    if mod.attach then
      vim.api.nvim_buf_call(buf, function() mod.attach(buf) end)
    end
  end,
})

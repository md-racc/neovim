-- =============================================================================
-- gen-keybinds.lua — generate KEYBINDS.md from the LIVE config
-- =============================================================================
-- KEYBINDS.md is generated, never hand-edited (it always drifted when it was).
-- This iterates vim.api.nvim_get_keymap() across modes plus the lua/lang/*
-- module tables, groups by leader prefix, and emits Markdown.
--
-- Run:  nvim --headless -u init.lua init.lua -c "luafile scripts/gen-keybinds.lua" -c qa
-- (opening a file suppresses the session auto-restore; the buffer is untouched).
--
-- Because `desc` is the single source of truth here, a mapping without a `desc`
-- is a bug — it shows up as "(no desc)" below.

local OUT = vim.fn.stdpath("config") .. "/KEYBINDS.md"

-- Group order + labels. `l` is dynamic (per language); its section is built
-- from the language modules instead of live maps.
local GROUPS = {
  { key = "b", label = "Buffer" },
  { key = "c", label = "Code" },
  { key = "d", label = "Debug" },
  { key = "f", label = "Find" },
  { key = "g", label = "Git" },
  { key = "o", label = "Open / external" },
  { key = "s", label = "Session" },
  { key = "t", label = "Test" },
  { key = "u", label = "UI / Toggles" },
  { key = "w", label = "Window" },
  { key = "x", label = "Diagnostics" },
}
local GROUP_KEYS = {}
for _, g in ipairs(GROUPS) do GROUP_KEYS[g.key] = g.label end

local MODES = { "n", "x", "v", "o", "i", "t" }

-- Force lazily-loaded keymap owners to register (so their maps are live).
pcall(function() require("lazy").load({ plugins = { "nvim-dap" } }) end)

-- Many +Code and +Git binds are buffer-local, set on LspAttach / gitsigns
-- attach. Open a tracked source file and wait for an LSP client so those maps
-- exist, then we can read them off that buffer below.
pcall(vim.cmd, "edit lua/config/lsp.lua")
vim.wait(6000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end, 100)
vim.wait(600) -- let the LspAttach/on_attach callbacks finish setting maps
local attached_buf = vim.api.nvim_get_current_buf()

-- Collect every mapping, keyed by a normalised lhs, remembering modes + desc.
-- Buffer-local maps from the attached buffer are merged in on top of globals.
local maps = {} -- lhs -> { desc = , modes = { n=true,... } }
local function ingest(list, mode)
  for _, m in ipairs(list) do
    local lhs = m.lhs
    local rec = maps[lhs] or { desc = m.desc, modes = {} }
    rec.modes[mode] = true
    if (not rec.desc or rec.desc == "") and m.desc then rec.desc = m.desc end
    maps[lhs] = rec
  end
end
for _, mode in ipairs(MODES) do
  ingest(vim.api.nvim_get_keymap(mode), mode)
  ingest(vim.api.nvim_buf_get_keymap(attached_buf, mode), mode)
end

local function modestr(rec)
  local order, out = { "n", "i", "x", "v", "o", "t" }, {}
  for _, mo in ipairs(order) do if rec.modes[mo] then out[#out + 1] = mo end end
  return table.concat(out, ",")
end

-- Non-leader maps we already document in the overrides table (skip in the
-- motions section to avoid duplication).
local OVERRIDE_KEYS = {
  ["n"] = true, ["N"] = true, ["s"] = true, ["S"] = true, ["r"] = true, ["R"] = true,
  ["-"] = true, ["<C-D>"] = true, ["<C-U>"] = true, ["<C-S>"] = true,
  ["<C-H>"] = true, ["<C-J>"] = true, ["<C-K>"] = true, ["<C-L>"] = true,
  ["<Esc>"] = true,
}

-- Neovim ships its own default normal-mode maps (0.11+): the `[`/`]` bracket
-- family, `&`, `Y`, `<C-W>d`, `gO`, ... They carry a `desc` too, so exclude them
-- to keep the motions section to *our* intentional binds.
local CORE_DENY = { ["&"] = true, ["Y"] = true, ["<C-W>d"] = true, ["<C-W><C-D>"] = true,
  ["gO"] = true, ["gx"] = true, ["gra"] = true, ["gri"] = true, ["grn"] = true,
  ["grr"] = true, ["grt"] = true, ["grx"] = true }
local function is_core_default(lhs, desc)
  if CORE_DENY[lhs] then return true end
  if not desc or desc == "" then return true end
  if desc:match("^:") then return true end                          -- ":rewind", ":help ..."
  if desc:match("empty line") then return true end                  -- [<Space> / ]<Space>
  if desc:match("diagnostic in the current buffer") then return true end -- [D / ]D
  return false
end

-- Split leader maps (lhs begins with the leader, a space) from motions.
local LEADER = vim.g.mapleader == " " and " " or vim.g.mapleader
local grouped, hot, motions = {}, {}, {}
for lhs, rec in pairs(maps) do
  local seq = lhs:sub(1, #LEADER) == LEADER and lhs:sub(#LEADER + 1) or nil
  if seq and seq ~= "" then
    local first = seq:sub(1, 1)
    if seq == LEADER then
      table.insert(hot, { lhs = "<leader><leader>", desc = rec.desc, modes = modestr(rec) })
    elseif first == "l" then
      -- +Language is buffer-local; documented from the module tables instead.
    elseif GROUP_KEYS[first] and #seq >= 2 then
      grouped[first] = grouped[first] or {}
      table.insert(grouped[first], { lhs = "<leader>" .. seq, desc = rec.desc, modes = modestr(rec) })
    else
      table.insert(hot, { lhs = "<leader>" .. seq, desc = rec.desc, modes = modestr(rec) })
    end
  elseif rec.modes.n and rec.desc and rec.desc ~= "" and not OVERRIDE_KEYS[lhs]
      and not lhs:match("^<Plug>") and not is_core_default(lhs, rec.desc) then
    -- Intentional non-leader normal-mode map (gd, gr, K, ]c/[c, ]d/[d, ]q/[q,
    -- <M-1>..<M-9>, <F5>..<F12>, ...).
    table.insert(motions, { lhs = lhs, desc = rec.desc, modes = "n" })
  end
end

local function by_lhs(a, b) return a.lhs < b.lhs end

local lines = {}
local function w(s) lines[#lines + 1] = s or "" end

w("# Keybindings")
w()
w("> Generated by `scripts/gen-keybinds.lua` from the live config — do not edit by hand.")
w("> Regenerate: `nvim --headless -u init.lua init.lua -c 'luafile scripts/gen-keybinds.lua' -c qa`")
w()
w("Leader is `<Space>`. Groups are semantic (noun-first): a bind's home is what")
w("it acts on, not which plugin renders it.")
w()

-- Portability note ------------------------------------------------------------
w("## Portability")
w()
w("`<S-CR>`, `<C-CR>`, `<M-1>`–`<M-9>` and `<C-Space>` rely on kitty's keyboard")
w("protocol. They will not work over SSH into a dumber terminal, or inside tmux")
w("without keyboard-protocol passthrough.")
w()

-- Vim defaults this config overrides -----------------------------------------
w("## Vim defaults this config overrides")
w()
w("| Key | Mode | Overridden behaviour |")
w("|-----|------|----------------------|")
w("| `s` / `S` | n,x,o | Flash jump / Flash treesitter (native `s`=substitute is sacrificed; `cc` covers `S`) |")
w("| `r` / `R` | o,x | Flash remote / treesitter-search operators |")
w("| `<Esc><Esc>` | t | Leave terminal mode (a single `<Esc>` passes through to TUIs) |")
w("| `J` / `K` | x | Move the selection down / up (re-indented) |")
w("| `<C-d>` / `<C-u>` | n | Half-page scroll, re-centred |")
w("| `n` / `N` | n | Next/prev search result, centred + folds opened (`nzzzv`) |")
w("| `-` | n | Open parent directory in Oil |")
w("| `<C-h/j/k/l>` | n | Focus window left/down/up/right |")
w("| `<C-s>` | n,i,v | Save (insert/visual return to normal) |")
w()

-- Hot tier --------------------------------------------------------------------
table.sort(hot, by_lhs)
w("## Hot tier — bare `<leader>` (frozen)")
w()
w("| Key | Modes | Action |")
w("|-----|-------|--------|")
for _, e in ipairs(hot) do
  w(("| `%s` | %s | %s |"):format(e.lhs, e.modes, e.desc or "(no desc)"))
end
w()

-- Domain groups ---------------------------------------------------------------
for _, g in ipairs(GROUPS) do
  local entries = grouped[g.key] or {}
  table.sort(entries, by_lhs)
  w(("## `<leader>%s` — +%s"):format(g.key, g.label))
  w()
  if #entries == 0 then
    w("_(no live maps found)_")
  else
    w("| Key | Modes | Action |")
    w("|-----|-------|--------|")
    for _, e in ipairs(entries) do
      w(("| `%s` | %s | %s |"):format(e.lhs, e.modes, e.desc or "(no desc)"))
    end
  end
  w()
end

-- Non-leader motions / LSP ----------------------------------------------------
table.sort(motions, by_lhs)
w("## Motions & LSP (non-leader)")
w()
w("| Key | Action |")
w("|-----|--------|")
for _, e in ipairs(motions) do
  w(("| `%s` | %s |"):format(e.lhs, e.desc or "(no desc)"))
end
w()

-- +Language (buffer-local) from the module tables ----------------------------
w("## `<leader>l` — +Language (buffer-local)")
w()
w("Populated per-buffer by the language dispatcher (`lua/lang/`). The same")
w("letter is the same verb in every language: `lb` build/check, `lr` run, `lR`")
w("run with args, `le` errors/output, `lx` execute, `lc`/`lC` callers/callees,")
w("`lt` type hierarchy.")
w()
local lang_files = vim.fn.globpath(vim.fn.stdpath("config") .. "/lua/lang", "*.lua", false, true)
table.sort(lang_files)
for _, f in ipairs(lang_files) do
  local name = vim.fn.fnamemodify(f, ":t:r")
  if name ~= "init" then
    local ok, mod = pcall(dofile, f)
    if ok and type(mod) == "table" and mod.maps then
      w(("### %s (`%s`)"):format(mod.name or name, name))
      w()
      w("| Key | Modes | Action |")
      w("|-----|-------|--------|")
      -- de-dupe lhs that appear in both n and x
      local seen = {}
      for _, m in ipairs(mod.maps) do
        local k = m[1]
        seen[k] = seen[k] or { modes = {}, desc = m.desc }
        seen[k].modes[m.mode or "n"] = true
      end
      local keys = {}
      for k in pairs(seen) do keys[#keys + 1] = k end
      table.sort(keys)
      for _, k in ipairs(keys) do
        local mo = {}
        for _, order in ipairs({ "n", "x", "v" }) do if seen[k].modes[order] then mo[#mo + 1] = order end end
        w(("| `<leader>%s` | %s | %s |"):format(k, table.concat(mo, ","), seen[k].desc or "(no desc)"))
      end
      w()
    end
  end
end
w("### LaTeX (`tex`) — VimTeX native `<localleader>l*`")
w()
w("No module: `maplocalleader` is `<Space>`, so VimTeX's own maps land in this")
w("namespace already — `ll` compile, `lv` view, `le` errors, `lk` stop, `lc` clean.")
w()

-- Reserved --------------------------------------------------------------------
w("## Reserved (free pool — do not squat)")
w()
local hot_letters = { e = true, y = true, Y = true, p = true, P = true, q = true, Q = true }
local used = { l = true } -- l is the +Language group (dynamic, per-buffer)
for k in pairs(GROUP_KEYS) do used[k] = true end
for k in pairs(hot_letters) do used[k] = true end
local free = {}
for c = string.byte("a"), string.byte("z") do
  local ch = string.char(c)
  if not used[ch] then free[#free + 1] = "`" .. ch .. "`" end
end
w("Top-level leader keys still free: " .. table.concat(free, " ") .. " plus `,` `.` `;` `'`.")
w()
w("Within each group, every letter not listed above is free. New toggles go to")
w("`<leader>u`; new languages get a file in `lua/lang/`; nothing new may be added")
w("to the hot tier.")
w()

-- Write -----------------------------------------------------------------------
local fd = assert(io.open(OUT, "w"))
fd:write(table.concat(lines, "\n"))
fd:close()
print("Wrote " .. OUT .. " (" .. #lines .. " lines)")

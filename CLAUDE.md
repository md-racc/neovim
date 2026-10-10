# CLAUDE.md

Guidance for working in this Neovim configuration. Read the **Axioms** before
changing any keymap — they are the spec, and the tables everywhere else are just
the axioms applied.

## What this is

A single-user Neovim 0.12 config (Arch Linux, kitty terminal, Wayland). Lua
only, `lazy.nvim` for plugins. It targets a C++-first workflow with solid
Python/Lua/Bash/LaTeX support.

## Branch `headless` (this branch)

Variant for the homelab dev VMs, shipped by the dotfiles `push` tool as a
**read-only** bundle (`git archive headless`, symlinked to `~/.config/nvim`,
hosts run as root). It is `main` minus: `lang/embedded.lua` and its hooks
(`lf*`, profile-aware clangd, on-chip DAP, ESP-IDF scaffold), cmake-tools
(`lm*`), cortex-debug, vimtex/tex snippets (`lang/tex.lua` keeps only the
prose buffer options, no `l*` labels), kitty-scrollback. Desktop-only bits
that stay in the code are gated in `main` by `lua/config/env.lua` (clipboard,
kitty spawns, treesitter CLI, notify-send, gio), so this branch only deletes.

- lazy never writes into the config dir: the committed `lazy-lock.json` is
  copied to `stdpath("state")` each start and used as the lockfile; checker and
  change detection are off; lazy.nvim itself is pinned at bootstrap.
- Only Neovim's bundled treesitter parsers (no `tree-sitter` CLI on hosts).
- Maintain by `git rebase main`; conflicts land only in the deleted parts.
  Regenerate `KEYBINDS.md` with `SSH_CONNECTION=x` set (so kitty maps drop out).

Embedded / LaTeX sections below describe `main` and do not apply here.

## Layout

```
init.lua                 -- options, appearance, plugin specs, require() order
lua/config/
  notify.lua             -- route vim.notify -> fnott (notify-send)
  ui.lua                 -- treesitter (main-branch, per-buffer attach), tree,
                            lualine, bufferline (+ instance tag), mini.clue
                            (leader-hint UI) + dormant which-key scaffolding,
                            +Buffer maps, tree startup
  session.lua            -- persistence + named workspaces, +Session
                            (loaded via the persistence plugin config)
  filemgmt.lua           -- git-aware + LSP-aware renames from nvim-tree
  editor.lua             -- conform, autopairs, files, fzf (+Find), terminal,
                            clipboard, +Window, +Git, +Diagnostics
  lsp.lua                -- servers (basedpyright/clangd/bashls/lua_ls), +Code
  completion.lua         -- nvim-cmp, C++ out-of-line definition stub hook
  autocmds.lua           -- yank flash, stale-buffer wipe, C/C++ filetypes,
                            xlsx BufReadCmd/BufWriteCmd hooks
  toggles.lua            -- the entire <leader>u (+UI/Toggles) namespace
  testing.lua            -- neotest (python + gtest), +Test  (loaded via plugin)
  dap.lua                -- nvim-dap + dap-ui, +Debug           (lazy)
  aerial.lua             -- code outline                        (lazy)
lua/lang/
  init.lua               -- FileType dispatcher for <leader>l (buffer-local)
  cpp.lua python.lua lua.lua sh.lua   -- one file per language
  tex.lua                -- labels vimtex's own maps (owns none itself)
  csv.lua                -- csv + tsv: csvview aligned view, check/sort/filter
  xlsx.lua               -- library: .xlsx -> read-only csv buffer
scripts/gen-keybinds.lua -- generates KEYBINDS.md from the live config
KEYBINDS.md              -- GENERATED. Never hand-edit.
```

`require()` order lives at the bottom of `init.lua`. `config.testing` is loaded
from the neotest plugin `config`, not the bottom block.

## Current state (2026-07-13)

The keymap layout was rebuilt into a semantic, noun-first namespace (see Axioms).
Everything below is live and verified:

- **12 groups:** `b`uffer `c`ode `d`ebug `f`ind `g`it `l`anguage `o`pen
  `s`ession `t`est `u`i-toggles `w`indow `x`-diagnostics. `l` is buffer-local.
- **Hot tier (frozen, never grows):** `<leader><leader>` resume picker,
  `<leader>e` tree, `y/Y p/P` clipboard, `q/Q` quit.
- **Python LSP is basedpyright** (installed; falls back to pyright if absent).
  Call/type hierarchy (`lc`/`lC`/`lt`) verified working.
- **Testing:** neotest with `neotest-python` and `neotest-gtest` (C++).
- **Leader-hint UI is mini.clue** (`echasnovski/mini.clue`), chosen over which-key
  because which-key's persistent floating window mispositions on the frequent
  `VimResized` events Hyprland fires. Global group labels are declared as
  mini.clue clues in `ui.lua` (icons baked into the group `desc`); leaf hints
  come from each mapping's `desc`. The `<leader>l` label (+C++, +Python,
  +LaTeX, ...) and the depth-3 sub-group labels (+CMake, +Flash/Device) are
  **buffer-local**, set via `vim.b.miniclue_config` by the language dispatcher
  (`lua/lang/init.lua`) / the tex autocmd — never global, because mini.clue
  shows clue-only entries and a global label would create phantom rows in other
  filetypes. **which-key is DEPRECATED** — kept as dormant scaffolding only
  (popup disabled via `triggers = {}`); the dispatcher still feeds it so a
  one-line revert works; safe to delete the block in `ui.lua` and its plugin
  spec once mini.clue has proven itself.
- **Treesitter is on the `main` branch** (the frozen `master` API is gone).
  Parsers are compiled via the `tree-sitter` CLI into `stdpath("data")/site`;
  `ui.lua` installs the guaranteed set and starts highlight + indent per buffer
  in a `FileType` autocmd (with on-demand install for other available parsers).
  No plugin in this config uses the old `nvim-treesitter.*` Lua API.
- **Theming is three layers:** lackluster (base colorscheme) →
  `apply_transparency()` in `init.lua` (transparent bg + hardcoded float/menu
  grays, re-applied on ColorScheme) → an optional wallust overlay
  (`~/.cache/wallust/nvim-colors.lua`, hot-reloaded via fs-watch for live
  wallpaper theming). `colors/laingrain.lua` is a hand-built colorscheme —
  a structural clone of lackluster recolored to the laingrain wallpaper's
  blue-gray palette, the nvim-side counterpart of
  `~/.config/wallust/colorschemes/laingrain.json`. It is load-bearing, not
  cruft: `:colorscheme laingrain` when that wallpaper is active.
- **Docs:** `KEYBINDS.md` is generated by `scripts/gen-keybinds.lua`.
  Regenerate after any keymap change:
  `nvim --headless -u init.lua init.lua -c 'luafile scripts/gen-keybinds.lua' -c qa`

### Tabular data (CSV / TSV / XLSX)

- `lua/lang/csv.lua` serves both `csv` and `tsv`. `csvview.nvim` aligns columns
  with virtual text (file never reformatted); treesitter is deliberately skipped
  for csv/tsv in `ui.lua` so the regex per-column rainbow syntax stays on.
  `layout(buf)` decides delimiter, leading `#` comment block, and header (a
  commented `# name<TAB>...` last comment line wins, else first row with no
  numeric cell) once, and feeds the same answer to csvview and `lb`/`ls`/`lx`.
  `setup_view()` also guards csvview's overlay `statuscolumn` against an
  upstream race (out-of-range lnum when `:copen` splits the window) — drop the
  guard if upstream fixes it.
- `.xlsx` is **read-only by design**: `lua/lang/xlsx.lua` converts one sheet to
  a csv buffer (`xlsx2csv`, fallback LibreOffice headless), `lw` switches sheet,
  `:w` refuses, `:w name.csv` exports. zipPlugin's `*.xlsx` BufReadCmd is cleared
  in `autocmds.lua` (it's sourced during `lazy.setup()`, before our config).
  Don't add write-back without accepting it's lossy (formulas/formatting/sheets).
- Filetype-only toggles (csv `lv`) live in `<leader>l`, not `<leader>u`:
  Axiom 5 wins over Axiom 6 when the toggle is meaningless outside the filetype.

### Embedded (ESP32 / STM32 / PlatformIO)

Embedded is a **profile inside C++**, not a language — the filetype stays
`c`/`cpp`; there is no new top-level group. `lua/lang/embedded.lua` (a library
required by `cpp.lua`, `lsp.lua`, `dap.lua`) detects the project at buffer-attach
and swaps backends behind the *same* universal verbs. See `~/SPEC-embedded.md`
and `docs/embedded.md`.

- **Three profiles, detected by root markers (first match wins, in this order):**
  1. `esp_idf` — `sdkconfig` / `sdkconfig.defaults`, or a CMakeLists with
     `include($ENV{IDF_PATH}` / `idf_component_register`.
  2. `platformio` — `platformio.ini`.
  3. `stm32` — a `.ioc`, or `CMakePresets.json` + an `*arm-none-eabi*.cmake`
     toolchain file, or a CMakeLists setting `CMAKE_TOOLCHAIN_FILE` to arm-none-eabi.
  None of the above ⇒ host C++, **unchanged**. Detection is cheap and silent.
- **Verbs swap backends, not letters:** `lb` build (`idf.py`/`cmake`/`pio`),
  `lr`/`lR` flash(+monitor)/flash-to-prompted-port, `le` build errors → quickfix.
  `lc`/`lC`/`lt`/`lh` unchanged (clangd).
- **`<leader>lf*` = +Flash/Device** (depth-3, embedded-only): `lff` flash, `lfm`
  monitor toggle, `lfe` erase (confirm-guarded), `lfp` port, `lfb` target/board,
  `lfc` menuconfig (IDF only), `lfs` size, `lfo` OpenOCD. `lm*` (CMake) is hidden
  under ESP-IDF/PlatformIO (they own their build system).
- **clangd is profile-aware** (`lsp.lua` clangd `cmd` is now a function): esp-clang
  for Xtensa, stock clangd for RISC-V, `--query-driver` (g++!) for STM32/PIO,
  `--compile-commands-dir` per build. **Host argv is byte-identical to before.**
- **On-chip debug** reuses `<leader>d` (no new keys): STM32 via cortex-debug,
  ESP32 via `idf.py openocd` + gdb DAP. Host dap config stays first. The esp
  gdbs are resolved through the captured export.sh env (`embedded.find_tool`),
  never the shell's PATH.
- **Dependencies are manifest-driven** (PlatformIO-style UX): saving
  `idf_component.yml` pulls the declared components (component manager runs at
  reconfigure) and re-indexes clangd; saving `platformio.ini` runs
  `pio run -t compiledb` and restarts clangd; saving `sdkconfig` re-indexes.
  No shell ever needs export.sh sourced — the env is captured once per session
  and passed per spawned job.
- **New project types = a `scaffold.lua` registry entry, never a bind.**
  `<leader>op` ("New project") is one key over `lua/config/scaffold.lua`'s
  generator list (C++/ESP-IDF/Python/Bash today). It scaffolds, `:tcd`s into the
  new root, and opens the entry file so FileType dispatch + detection fire for
  free. No `op*` sub-map, ever (it's an enum — see Axiom 4).

### Known / accepted

- `REPORT.md` is stale (describes a long-gone telescope/mason/ide.lua layout).
  Not load-bearing; ignore or delete, don't trust it.
- which-key is dormant/deprecated (see above); mini.clue owns the leader menu.
- Oil and NvimTree coexist deliberately (redundancy accepted for now).
- CMake (`<leader>lm*`) and Flash/Device (`<leader>lf*`) are depth-3 sub-groups
  inside +C++ — the two sanctioned exceptions to the depth-2 rule (Axiom 4).
  `lf*` only registers in detected embedded projects.
- kitty-protocol keys (`<S-CR> <C-CR> <M-1..9> <C-Space>`) don't survive SSH to
  a dumb terminal or tmux without passthrough.

## Axioms (rules for future development)

These are invariant. When a case is ambiguous, resolve it with these, not by
preserving old behaviour.

1. **Noun-first, never plugin-first.** A bind's home is decided by *what it acts
   on*, not which plugin provides it. Git commits live under `g` even though fzf
   renders them; symbols under `c`; diagnostics under `x`.
2. **Top level is domain groups only**, plus the frozen hot tier. The hot tier
   is **closed** — no new bind may ever be added to it.
3. **Shift = same concept, wider scope.** `cs`/`cS` = document/workspace
   symbols; `gs`/`gS` = stage hunk/buffer. Shift **never** switches concept.
4. **Depth 2 is the ceiling** (`<leader>{group}{key}`). A third level is legal
   only if a group exceeds ~10 keys *and* the split is a genuine sub-noun.
   Current instances: `lm` (CMake) and `lf` (Flash/Device); both live inside the
   buffer-local `<leader>l` namespace. A third level in a *global* group remains
   forbidden.
   - **Enums are not sub-groups.** A sub-group is a *noun with multiple verbs*
     (`lm` CMake: build/run/debug/select; `lf` Device: flash/monitor/erase/port).
     One verb with many possible arguments is an **enum**, and enums belong in a
     `vim.ui.select` picker, not in keys. Keys are for high-frequency, low-arity
     choices; pickers are for low-frequency, high-arity ones. (This is why
     `<leader>op` "New project" is one key over a registry, never an `op*`
     sub-map — see the Embedded notes below.)
5. **Filetype-specific ⇒ `<leader>l`.** The global namespace must not grow when
   a language is added. Adding a language = **one new file** in `lua/lang/`,
   nothing else.
6. **Toggles ⇒ `<leader>u`.** Anything idempotent or view-mode-switching. This
   is the drain that keeps the top level from accreting one-offs.
7. **Every mapping declares `desc`.** Non-negotiable: `desc` is the single
   source of truth for both which-key and the generated docs. A mapping without
   `desc` is a bug — it surfaces as `(no desc)` in `KEYBINDS.md`.

### The universal verb contract (`<leader>l`)

The same letter is the same verb in **every** language module. Do not deviate
per-language:

| Key | Meaning |
|-----|---------|
| `lb` | Build / check — the "is it correct" action |
| `lr` / `lR` | Run current file / run with args (prompt) |
| `le` | Errors / last output |
| `lx` | Execute — selection (v) / line or file (n) |
| `lc` / `lC` | Call hierarchy: callers / callees |
| `lt` | Type hierarchy |

A language module returns `{ name, groups?, maps, filter?, labels?, attach? }`; each map is
`{ "lX", rhs, desc = "...", mode = "n" }` where the lhs is `<leader>` .. `lX`.
The optional `filter(buf, lhs) -> bool` lets a module keep `maps` a static
superset (so the docs generator, which `dofile`s the module, lists every bind)
while registering only the subset that fits the buffer — used by `cpp.lua` to
show the embedded `lf*` sub-group and hide `lm*` per detected profile.
`labels` (lhs → desc) names maps a *plugin* created (tex.lua over vimtex);
`attach(buf)` does per-buffer setup (options, enabling a view). Adding a
language also means one line in the `MODULE` filetype table in `lang/init.lua`.

### Clipboard

Do **not** set `clipboard=unnamedplus`. Plain `y`/`p` never touch the system
clipboard; only the explicit `"+` maps (`<leader>y/Y/p/P`) do. Visual paste must
keep `"+` intact across repeated pastes (replaced text goes to the unnamed
register).

### Docs

`KEYBINDS.md` is generated, never written. If you touch keymaps, regenerate it
(command above). Because `desc` is the source of truth, keep descriptions short
and action-oriented.

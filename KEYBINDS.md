# Neovim Keybind Reference

> Search tip: use `/pattern` in nvim, or `grep -i keyword KEYBINDS.md`
> Leader key: `<Space>`

---

## Table of Contents

- [File](#file)
  - [Sudo Escalation](#sudo-escalation--sudanvim)
- [Directory Navigation](#directory-navigation)
- [FZF / Find — `<leader>f`](#fzf--find--leaderf)
- [Search](#search)
- [Clipboard](#clipboard)
- [Delete](#delete)
- [Windows & Splits](#windows--splits)
- [Buffers](#buffers)
- [Flash — Motion](#flash--motion)
- [Oil — File Manager](#oil--file-manager)
- [Surround](#surround)
- [Commenting](#commenting)
- [Completion](#completion)
- [Autopairs](#autopairs)
- [Git](#git)
- [Diagnostics](#diagnostics)
- [LSP](#lsp)
- [C / C++](#c--c)
- [Debugging — DAP](#debugging--dap)
- [Testing — Neotest](#testing--neotest)
- [Sessions](#sessions)
  - [Named Workspaces](#named-workspaces)
- [File Tree — NvimTree](#file-tree--nvimtree)
- [Terminal](#terminal)
- [LaTeX](#latex)
- [Markdown](#markdown)
- [Auto-Behaviours](#auto-behaviours)

---

## File

| Key | Action |
|-----|--------|
| `<leader>w` | Save buffer |
| `<leader>q` | Quit |
| `<leader>Q` | Save all and quit |
| `<leader>F` | Format buffer (conform, LSP fallback) |
| `<leader>h` | Spawn kitty terminal at current file's directory |
| `<leader>R` | Toggle auto-resize splits on terminal resize |

### Sudo Escalation — `suda.nvim`

Reads and writes through `sudo`, triggering PAM authentication in the terminal.
Useful for system files (`/etc/...`) owned by root.

| Key | Action |
|-----|--------|
| `<leader>sur` | Re-read current file with sudo (escalated open) |
| `<leader>suw` | Write current buffer to its path with sudo |

Raw commands `:SudaRead [path]` and `:SudaWrite [path]` also work if targeting a path directly.

---

## Directory Navigation

| Key | Action |
|-----|--------|
| `-` | Open parent directory in Oil |
| `=` | Directory jumper (fd + fzf, cds nvim + updates tree) |

`=` scans `/home`, `/etc`, and `/root`. Displays the last 3–4 path components for readability; the full path is used for the actual `cd`.

**On confirm:** all listed buffers are closed before jumping. If any buffer has unsaved changes the jump is aborted and the offending files are listed in the notification — save them first.

---

## FZF / Find — `<leader>f`

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files (from cwd) |
| `<leader>fg` | Live grep |
| `<leader>fb` | Open buffers |
| `<leader>fr` | Recent files |
| `<leader>fs` | Document symbols (LSP) |
| `<leader>fS` | Workspace symbols (LSP) |
| `<leader>fd` | Buffer diagnostics |
| `<leader>fD` | Workspace diagnostics |
| `<leader>fGc` | Git commits |
| `<leader>fGb` | Git branches |
| `<leader>fe` | Reload file with selected encoding |
| `<leader>fv` | View file as bytes — hex / binary / octal / decimal / ascii |

### `<leader>fe` — Encoding picker

Reloads the buffer interpreted under the chosen encoding. Useful when auto-detection is wrong.

Available encodings: `utf-8`, `utf-16`, `utf-16le`, `utf-16be`, `utf-32`, `utf-32le`, `utf-32be`,
`latin1`, `iso-8859-2`, `iso-8859-15`, `cp1252`, `cp1251`, `cp437`,
`shift-jis`, `euc-jp`, `euc-kr`, `gb2312`, `big5`

### `<leader>fv` — Byte view picker

Pipes the buffer through the chosen tool. `u` undoes any view.

| Label | Tool | Notes |
|-------|------|-------|
| `hex` | `xxd` | Default annotated hex dump |
| `hex plain` | `xxd -p` | Raw hex, no offsets |
| `binary` | `xxd -b` | Bit-level view |
| `octal` | `od -A x -t o1z -v` | Octal bytes with ASCII |
| `decimal` | `od -A x -t d1z -v` | Decimal bytes with ASCII |
| `ascii` | `od -c` | Escaped ASCII representation |
| `revert` | `xxd -r` | Undo xxd back to raw bytes |

---

## Search

| Key | Action |
|-----|--------|
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next match (cursor centred) |
| `N` | Previous match (cursor centred) |
| `<Esc>` | Clear search highlight |

---

## Clipboard

Wayland system clipboard via `wl-clipboard`. Register: `"+`.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>y` | n, v | Yank selection to clipboard |
| `<leader>Y` | n | Yank to end of line to clipboard |
| `<leader>p` | n, v | Paste from clipboard (after) |
| `<leader>P` | n, v | Paste from clipboard (before) |

---

## Delete

Delete into black hole register — clipboard is not overwritten.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>d` | n, v | Delete without clipboard |
| `<leader>dd` | n | Delete line without clipboard |

---

## Windows & Splits

| Key | Action |
|-----|--------|
| `<C-h>` | Focus window left |
| `<C-j>` | Focus window down |
| `<C-k>` | Focus window up |
| `<C-l>` | Focus window right |
| `<leader>sv` | Open vertical split |
| `<leader>sh` | Open horizontal split |
| `<leader>sr` | Mark focused buffer as reference (hides from bufferline, returns focus to previous window) |
| `<C-d>` | Scroll half-page down (cursor centred) |
| `<C-u>` | Scroll half-page up (cursor centred) |

### Visual mode

| Key | Action |
|-----|--------|
| `J` | Move selected lines down |
| `K` | Move selected lines up |

---

## Buffers

| Key | Action |
|-----|--------|
| `<C-t>` | New empty buffer |
| `<C-w>` | Close buffer (smart: switches away first to preserve splits) |
| `<M-1>` … `<M-9>` | Jump to buffer 1–9 (bufferline position) |
| `<leader>be` | Eject buffer to a new kitty window running its own nvim instance |
| `<leader>I` | Set this instance's tag (prompt) — also `:Tag <name>` |

### Instance tag

A free-text label shown in the **top-right of the tab bar** to tell apart
multiple nvim instances (e.g. same project, different branches). Set it with
`<leader>I` (prompts) or `:Tag <name>` directly; `:Tag` with no argument opens
the prompt pre-filled with the current tag (clear it by submitting empty). The
tag is stored in `g:NvimTag` and **persists** — it is saved into named
workspaces (`<leader>Sw`) and the auto-saved session, and restored on load
(via `sessionoptions+=globals`).

### `<leader>be` — Buffer eject

Opens the current file in a detached kitty os-window at the same line, then closes the buffer from this instance. Aborts if the buffer has no file or has unsaved changes.

---

## Flash — Motion

Two-character jump to anywhere on screen.

| Key | Mode | Action |
|-----|------|--------|
| `s` | n, x, o | Flash jump — type 2 chars, pick label |
| `S` | n, x, o | Flash treesitter — jump to a syntax node |
| `r` | o | Flash remote — act on a remote location without moving cursor (e.g. `yr{flash}`) |
| `R` | o, x | Flash treesitter search — treesitter node as operator target |

---

## Oil — File Manager

Edit the filesystem like a buffer. `:w` applies changes.

| Key | Context | Action |
|-----|---------|--------|
| `-` | normal | Open parent directory in Oil |
| `-` | Oil buffer | Go up one directory |
| `Enter` | Oil buffer | Enter directory / open file |
| `:w` | Oil buffer | Apply pending renames / deletes / moves |
| `g?` | Oil buffer | Show Oil help |

Hidden files are shown by default. Deletions go to the trash (recoverable), not `rm`.

---

## Surround

`nvim-surround` — add, change, delete surrounding pairs.

| Key | Action | Example |
|-----|--------|---------|
| `ys{motion}{char}` | Add surround | `ysiw"` wraps word in `"` |
| `yss{char}` | Surround whole line | `yss)` wraps line in `()` |
| `cs{old}{new}` | Change surround | `cs'"` changes `'` to `"` |
| `ds{char}` | Delete surround | `ds"` removes surrounding `"` |

---

## Commenting

`Comment.nvim` with treesitter context — picks correct token per language / embedded scope.

| Key | Mode | Action |
|-----|------|--------|
| `gcc` | n | Toggle line comment |
| `gc{motion}` | n | Comment over motion (e.g. `gcap` for paragraph) |
| `gc` | v | Toggle comment on selection |
| `gbc` | n | Toggle block comment (`/* */` style) |
| `gb{motion}` | n | Block comment over motion |

---

## Completion

`nvim-cmp` — triggers after 3 characters.

| Key | Action |
|-----|--------|
| `<C-Space>` | Force open completion menu |
| `<CR>` | Confirm selected item |
| `<Tab>` | Next item / expand snippet / jump to next snippet placeholder |
| `<S-Tab>` | Previous item / jump to previous snippet placeholder |

Sources (in priority order): LSP → LuaSnip → buffer → path.
TeX buffers also include VimTeX (`\ref`, `\cite`, `\label`).

### Autopairs

| Key | Action |
|-----|--------|
| `(`, `[`, `{`, `"`, `'` | Auto-closes matching pair |
| `<C-l>` (insert) | Jump over next closing bracket without inserting |

---

## Git

### Gitsigns — hunk-level

| Key | Action |
|-----|--------|
| `]c` | Next hunk |
| `[c` | Previous hunk |
| `<leader>gs` | Stage hunk |
| `<leader>gr` | Reset hunk |
| `<leader>gp` | Preview hunk inline |
| `<leader>gb` | Toggle current line blame |

### Lazygit

| Key | Action |
|-----|--------|
| `<leader>gg` | Open Lazygit (full TUI) |

---

## Diagnostics

| Key | Action |
|-----|--------|
| `]d` | Next diagnostic |
| `[d` | Previous diagnostic |
| `<leader>xx` | Toggle workspace diagnostics (Trouble) |
| `<leader>xb` | Toggle buffer diagnostics (Trouble) |

---

## LSP

Active on attach for: `pyright` (Python), `clangd` (C/C++), `bashls` (Bash), `lua_ls` (Lua).

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover documentation |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code actions |

### C++ only (clangd)

| Key | Action |
|-----|--------|
| `<leader>ci` | Toggle inlay hints |
| `<leader>ch` | Switch between header and source file |

### C++ stub generation (nvim-treesitter-cpp-tools)

Generate out-of-line definitions from header declarations, written straight
into the matching `.cpp`.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>cd` | n | Define the declaration under the cursor → `.cpp` |
| `<leader>cd` | v | Define every declaration in the selection → `.cpp` (select the class body to do all at once) |
| `<leader>c3` | n | Generate rule of 3 (copy ctor, copy assign, dtor) |
| `<leader>c5` | n | Generate rule of 5 (+ move ctor, move assign) |

The generated `.cpp` opens in a split with `Class::method(...) {}` stubs ready to
fill in; `:w` to save.

---

## C / C++

Available in `c` and `cpp` buffers.

| Key | Action |
|-----|--------|
| `<leader>cr` | Compile all `.cpp` in directory → `/tmp/cpp_out` and run (C++17, -Wall) |
| `<leader>cc` | Compile all `.cpp` in directory → binary beside source |

Format on save is automatic (clang-format via conform).

---

## Debugging — DAP

Auto-opens/closes DAP UI with the debug session.

| Key | Action |
|-----|--------|
| `<F5>` | Continue |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>Db` | Toggle breakpoint |
| `<leader>DB` | Conditional breakpoint (prompts for expression) |
| `<leader>Dr` | Open DAP REPL |
| `<leader>Du` | Toggle DAP UI |

### Adapters

| Language | Backend | Requirement |
|----------|---------|-------------|
| Python | debugpy | `pacman -S python-debugpy` |
| C / C++ | gdb (`--interpreter=dap`) | `pacman -S gdb` |

---

## Testing — Neotest

| Key | Action |
|-----|--------|
| `<leader>nt` | Run nearest test |
| `<leader>nf` | Run all tests in current file |
| `<leader>ns` | Toggle test summary panel |
| `<leader>no` | Toggle test output panel |

Adapters: `neotest-python`.

---

## Sessions

`persistence.nvim` — auto-saves session on quit, auto-restores on open (when no file args given).

| Key | Action |
|-----|--------|
| `<leader>Sl` | Load session for current working directory |
| `<leader>Ss` | Stop session saving (session discarded on quit) |

### Named Workspaces

Explicitly named sessions stored in `~/.local/share/nvim/workspaces/`. Independent of the per-cwd auto-sessions above — save and restore by name from any directory.

| Key | Action |
|-----|--------|
| `<leader>Sw` | Save current layout as a named workspace (prompts for name) |
| `<leader>So` | Open a named workspace via fzf picker |

Workspaces capture open buffers, splits, tabs, cursor positions, and cwd. Terminal buffers do not restore cleanly — close them before saving.

---

## File Tree — NvimTree

Opens automatically on `VimEnter` (focus returns to editing window).

| Key | Context | Action |
|-----|---------|--------|
| `<leader>e` | normal | Toggle file tree |
| `<CR>` | NvimTree | Directory: toggle expand/collapse. File: open in current window |
| `<S-CR>` | NvimTree | Directory: new kitty nvim with that dir as cwd. File: new kitty nvim opening the file |
| `<C-CR>` | NvimTree | Directory: cd here + reroot tree. File: open in vertical split |
| `<BS>` | NvimTree | cd up to parent directory + reroot tree (inverse of `<C-CR>` on a dir) |
| `<Tab>` | NvimTree | Preview file under cursor without leaving the tree |
| `y` | NvimTree | Copy node's absolute path to system clipboard |
| `a` | NvimTree | Create file or directory |
| `d` | NvimTree | Trash (recoverable via `gio trash`) |
| `D` | NvimTree | Delete permanently |
| `r` | NvimTree | Rename (LSP rewrites importers; move is staged as a git rename) |
| `R` | NvimTree | Refresh tree |
| `H` | NvimTree | Toggle hidden files |
| `gy` | NvimTree | Copy relative path (nvim-tree default) |

Create/rename/delete feedback (and all `vim.notify` messages) is routed to
**dunst** via `notify-send` instead of the command line, so file actions no
longer need extra `<CR>` presses to dismiss a "Press ENTER" prompt. Repeated
messages from the same source replace each other (dunst stack tags) rather than
stacking up. Configured in `lua/config/notify.lua`.

---

## Terminal

| Key | Mode | Action |
|-----|------|--------|
| `<leader>t` | n | Open terminal in right vertical split |
| `<leader>h` | n | Spawn new kitty window at current file's directory |
| `<Esc>` | terminal | Exit terminal mode (back to normal mode) |

Terminal buffers start in insert mode automatically.

---

## LaTeX

Activated on `tex` filetype. VimTeX keymaps live under `<leader>l`.
Auto-installs texlive if `latexmk` is not found.

| Setting | Value |
|---------|-------|
| `conceallevel` | 2 |
| `spell` | on |
| `wrap` / `linebreak` | on |

See `:help vimtex-mappings` for the full VimTeX keymap reference.
Common ones: `<leader>ll` compile, `<leader>lv` view PDF, `<leader>le` errors.

---

## Markdown

Activated on `markdown` filetype.

| Setting | Value |
|---------|-------|
| `wrap` / `linebreak` / `breakindent` | on |
| `conceallevel` | 2 |
| `textwidth` | 0 (disabled) |

In-buffer rendering via `render-markdown.nvim` (headers, code blocks, lists styled inline).

---

## Auto-Behaviours

| Trigger | Behaviour |
|---------|-----------|
| Yank | Briefly flashes yanked region (150ms, `IncSearch` highlight) |
| Terminal resize | Re-equalises all splits (`<leader>R` to toggle on/off) |
| File changed externally | Auto-reloads on focus / buffer enter / cursor hold |
| Open real file | Wipes stale empty unnamed buffer |
| C/C++ save | Runs clang-format automatically |
| Terminal open | Enters insert mode, hides line numbers and signcolumn |
| NvimTree open | Opens on startup, focus returns to editor |
| Session | Auto-saves on quit, auto-restores when opening nvim in a directory |
| Cursor moved | Viewport snaps back to the left border whenever the cursor fits within the window width — prevents the view staying scrolled right after navigating back from a long line |

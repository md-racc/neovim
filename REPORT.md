# Neovim IDE setup report (Lazy + Mason + LSP + basic UI)

## Overview
This setup targets Neovim 0.11 on Arch Linux. The configuration is split to avoid double-loading:

- `init.lua` bootstraps `lazy.nvim`, declares plugins, and `require("ide")`.
- `lua/ide.lua` contains all IDE configuration.

The layout avoids `mason-lspconfig.setup_handlers` (v2 API change) and keeps LSP explicit.

## File layout

- `~/.config/nvim/init.lua`
- `~/.config/nvim/lua/ide.lua`

## Plugins used

Core:
- `lazy.nvim` (plugin manager)
- `mason.nvim` (binary installer)
- `nvim-lspconfig` (LSP client wiring)
- `nvim-cmp` + `cmp-nvim-lsp` + `cmp-buffer` + `cmp-path` + `LuaSnip` + `cmp_luasnip` (completion)
- `nvim-treesitter` (syntax highlighting)

UI + navigation:
- `telescope.nvim`
- `nvim-tree`
- `lualine`
- `gitsigns`
- `trouble`

## Arch Linux system packages

Required:
```
sudo pacman -S tree-sitter-cli ripgrep fd nodejs npm python-pip
```

Optional but recommended:
```
sudo pacman -S shellcheck shfmt python-pynvim
```

## Mason installs (confirmed working)

Install in `:Mason`:
- `bashls` (bash-language-server)
- `clangd`
- `lua_ls` (lua-language-server)
- `pyright`

## Key configuration points

### `init.lua`
- Bootstraps `lazy.nvim` if missing.
- Declares plugin list.
- Delegates IDE setup to `require("ide")`.

### `lua/ide.lua`
- Treesitter: highlight + indent enabled.
- Telescope: leader mappings for files, grep, buffers, help.
- Nvim-tree: leader toggle on `<leader>e`.
- Lualine: `globalstatus = true`.
- Mason + LSP: explicit server setup with CMP capabilities.
- LSP keymaps on `LspAttach`.

## Verification commands

Inside Neovim:
- `:Lazy sync`
- `:Mason` (ensure servers installed)
- Open `test.py`, run `:LspInfo` (expect 1 `pyright` client)
- `:checkhealth nvim-treesitter` (must find `tree-sitter-cli`)

## Common gotchas and fixes

- `module 'lazy' not found`: missing bootstrap block or `rtp` prepend.
- `tree-sitter-cli not found`: install `tree-sitter-cli` (not `tree-sitter`).
- LSP framework deprecation stacktrace: update `nvim-lspconfig` via `:Lazy update`.
- Double pyright clients: caused by double-loading or auto-config; keep config split and explicit.

## Clipboard note

To delete without overriding clipboard:
- Use black hole register: `"_d` or line delete `"_dd`.

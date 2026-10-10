-- =============================================================================
-- ENVIRONMENT — what this nvim session can reach
-- =============================================================================
-- One place for the "am I on the desktop or over ssh" checks, so desktop-only
-- code is gated by a named capability instead of failing at runtime. Evaluated
-- once at startup; on the desktop every flag is true and behaviour is unchanged.

local function has(bin) return vim.fn.executable(bin) == 1 end

local M = {}

M.ssh         = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
M.tmux        = vim.env.TMUX ~= nil
-- wl-clipboard on the machine we're sitting at. Deliberately not keyed on
-- WAYLAND_DISPLAY: the desktop provider always bypassed that detection (it can
-- be missing in some local launches), and over ssh wl-copy can't reach us.
M.has_wayland = has("wl-copy") and not M.ssh
-- Spawning a kitty window only makes sense on the machine we're sitting at.
M.has_kitty   = has("kitty") and not M.ssh
M.has_notify  = has("notify-send")
-- nvim-treesitter (main) compiles parsers with the tree-sitter CLI.
M.has_ts_cli  = has("tree-sitter")
M.has_gio     = has("gio")

M.has = has

return M

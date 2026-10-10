-- =============================================================================
-- CLIPBOARD PROVIDER — where "+ goes
-- =============================================================================
-- Same order as the dotfiles' shell `_clip` and vimrc:
--   1. local Wayland session      -> wl-clipboard
--   2. inside tmux                -> tmux buffer (-w forwards it to the outer
--                                    terminal via OSC 52, independent of tmux's
--                                    set-clipboard setting)
--   3. anything else (plain ssh)  -> OSC 52 straight to the terminal
-- Only the provider is chosen here. clipboard=unnamedplus stays unset: plain y/p
-- never touch "+, only the explicit <leader>y/p maps do (lua/config/editor.lua).

local env = require("config.env")

if env.has_wayland then
  vim.g.clipboard = {
    name  = "wl-clipboard",
    copy  = { ["+"] = "wl-copy",              ["*"] = "wl-copy" },
    paste = { ["+"] = "wl-paste --no-newline", ["*"] = "wl-paste --no-newline" },
    cache_enabled = 0,
  }
elseif env.tmux then
  vim.g.clipboard = {
    name  = "tmux",
    copy  = { ["+"] = { "tmux", "load-buffer", "-w", "-" },
              ["*"] = { "tmux", "load-buffer", "-w", "-" } },
    paste = { ["+"] = { "tmux", "save-buffer", "-" },
              ["*"] = { "tmux", "save-buffer", "-" } },
    cache_enabled = 0,
  }
else
  -- Copy goes out as OSC 52. Paste deliberately does NOT ask the terminal (many
  -- never answer, and the built-in reader then blocks for up to 10s): it returns
  -- what we last copied, else the unnamed register. Pasting from the outer
  -- machine is the terminal's own job (kitty's paste key).
  local osc52 = require("vim.ui.clipboard.osc52")
  local last  = {}
  local function copy(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype)
      last[reg] = { lines, regtype }
      send(lines)
    end
  end
  local function paste(reg)
    return function()
      return last[reg] or { vim.fn.getreg('"', 1, true), vim.fn.getregtype('"') }
    end
  end
  vim.g.clipboard = {
    name  = "OSC 52",
    copy  = { ["+"] = copy("+"),  ["*"] = copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
end

-- =============================================================================
-- NOTIFICATIONS — route vim.notify to dunst (notify-send)
-- =============================================================================
-- The built-in vim.notify echoes to the command line, which triggers the
-- "Press ENTER" hit-enter prompt — e.g. creating a file with `a` in nvim-tree
-- costs extra keypresses just to dismiss the "Created file ..." message.
-- Sending these to dunst instead makes them non-blocking desktop popups, so a
-- create/rename/delete is a single keystroke again.
--
-- Only replaces vim.notify when notify-send exists; otherwise the default
-- behaviour is left untouched. Hard errors (Lua tracebacks, :echoerr) do not
-- go through vim.notify, so they still surface inline as before.

if vim.fn.executable("notify-send") ~= 1 then return end

local urgency = {
  [vim.log.levels.ERROR] = "critical",
  [vim.log.levels.WARN]  = "normal",
  [vim.log.levels.INFO]  = "low",
  [vim.log.levels.DEBUG] = "low",
  [vim.log.levels.TRACE] = "low",
}

local original = vim.notify

local function dunst_notify(msg, level, opts)
  if type(msg) == "table" then
    msg = table.concat(msg, "\n")
  end
  msg = tostring(msg)
  level = level or vim.log.levels.INFO
  opts = opts or {}
  local title = opts.title or "Neovim"

  local args = {
    "notify-send",
    "-a", "nvim",
    "-u", urgency[level] or "low",
    -- Stack tag = title, so repeated messages from the same source (e.g.
    -- "NvimTree") replace the previous popup instead of piling up.
    "-h", "string:x-dunst-stack-tag:nvim-" .. title,
    title,
    msg,
  }

  local ok = pcall(function()
    if vim.system then
      vim.system(args, { text = true })
    else
      vim.fn.jobstart(args, { detach = true })
    end
  end)
  -- If the desktop call somehow fails, fall back to the built-in notifier so a
  -- message is never silently lost.
  if not ok then
    original(msg, level, opts)
  end
end

vim.notify = dunst_notify

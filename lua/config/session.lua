-- =============================================================================
-- SESSION  (+Session, <leader>s) — persistence.nvim + named workspaces
-- =============================================================================
-- Invoked from the persistence plugin config in init.lua (so persistence is
-- loaded when this runs), mirroring how config.testing is loaded from neotest.

require("persistence").setup()

-- Prep the buffer/global state so a session captures only real work.
--
--  1. nvim-tree: keep it entirely out of sessions — it's trivial to
--     toggle (<leader>e) and is always freshly opened on startup, so it
--     should never be restored. Closing the window alone isn't enough:
--     nvim-tree also sets MixedCase globals (g:NvimTreeSetup /
--     g:NvimTreeRequired) that ride along via sessionoptions+=globals
--     (added for g:NvimTag) and re-inject stale tree state.
--
--  2. Phantom buffers: various tools (clangd/LSP, plugins) leave behind a
--     *listed, normal, empty, unsaved* buffer whose name points at no file
--     on disk (e.g. an empty "Widget."). mksession badd's these, so they
--     re-open as blank buffers on restore. Wipe them — they hold nothing.
local function strip_tree()
  pcall(vim.cmd, "NvimTreeClose")
  local ok, out = pcall(function()
    return vim.api.nvim_exec2("let g:", { output = true }).output
  end)
  if ok then
    for line in out:gmatch("[^\n]+") do
      local name = line:match("^(NvimTree%w*)")
      if name then pcall(function() vim.g[name] = nil end) end
    end
  end
end

local function prune_phantom_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b)
      and vim.fn.buflisted(b) == 1
      and vim.bo[b].buftype == ""
      and not vim.bo[b].modified then
      local name = vim.api.nvim_buf_get_name(b)
      -- Named, but no such file on disk...
      if name ~= "" and vim.uv.fs_stat(name) == nil then
        local lc    = vim.api.nvim_buf_line_count(b)
        local first = lc > 0 and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] or ""
        -- ...and empty => a phantom placeholder, safe to wipe.
        if lc <= 1 and first == "" then
          pcall(vim.api.nvim_buf_delete, b, { force = true })
        end
      end
    end
  end
end

-- Drop argument-list entries whose files no longer exist. mksession always
-- persists the arglist, and `argadd <missing>` re-spawns an empty phantom
-- buffer on every restore (e.g. a deleted cpp-completion-test/Widget.
-- haunting the home session). Rebuild the list keeping only real files.
local function prune_dead_args()
  local args = vim.fn.argv()
  if type(args) ~= "table" or #args == 0 then return end
  local keep = {}
  for _, a in ipairs(args) do
    if vim.uv.fs_stat(vim.fn.fnamemodify(a, ":p")) then keep[#keep + 1] = a end
  end
  if #keep ~= #args then
    pcall(vim.cmd, "silent! %argdelete")
    if #keep > 0 then
      pcall(vim.cmd, "silent! argadd "
        .. table.concat(vim.tbl_map(vim.fn.fnameescape, keep), " "))
    end
  end
end

local function prepare_session()
  strip_tree()
  prune_phantom_buffers()
  prune_dead_args()
end

vim.api.nvim_create_autocmd("User", {
  pattern  = "PersistenceSavePre",
  callback = prepare_session,
})
-- Restore session when nvim is opened in a directory with no file args
vim.api.nvim_create_autocmd("VimEnter", {
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 then require("persistence").load() end
  end,
})
vim.keymap.set("n", "<leader>sl", function() require("persistence").load() end,
  { silent = true, desc = "Load session for cwd" })
vim.keymap.set("n", "<leader>ss", function() require("persistence").stop() end,
  { silent = true, desc = "Stop saving session (discard on quit)" })

-- Save the current session NOW as the unnamed autosave for this cwd
-- (persistence.save writes M.current() — the same file the quit-time
-- autosave and startup restore use). Named workspaces are untouched.
-- Close the tree first (as PersistenceSavePre does on quit) so the tree
-- window isn't captured and re-collided on restore, then reopen it.
vim.keymap.set("n", "<leader>sp", function()
  local tree   = require("nvim-tree.api").tree
  local reopen = tree.is_visible()
  prepare_session()
  require("persistence").save()
  if reopen then tree.open() end
  vim.notify("Session autosave overwritten")
end, { silent = true, desc = "Save session (overwrite autosave)" })

-- Named workspaces: save and restore by name across any directory
local ws_dir = vim.fn.stdpath("data") .. "/workspaces/"
vim.fn.mkdir(ws_dir, "p")

-- Source a workspace robustly:
--   * Run outside any fzf-lua action context (via the caller's schedule)
--     so the session's `cd` sticks instead of being reverted by fzf.
--   * Auto-resolve swap prompts (E325) that would otherwise throw when a
--     restored file has a stale or foreign swap; "e" opens it anyway.
local function load_workspace(path)
  local grp = vim.api.nvim_create_augroup("WorkspaceLoadSwap", { clear = true })
  vim.api.nvim_create_autocmd("SwapExists", {
    group = grp,
    callback = function() vim.v.swapchoice = "e" end,
  })
  local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(path))
  pcall(vim.api.nvim_del_augroup_by_id, grp)
  if not ok then
    vim.notify("Workspace load failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

vim.keymap.set("n", "<leader>sw", function()
  vim.ui.input({ prompt = "Workspace name: " }, function(name)
    if not name or name == "" then return end
    -- Keep the tree + phantom buffers out of the session (see
    -- prepare_session).
    local tree = require("nvim-tree.api").tree
    local reopen = tree.is_visible()
    prepare_session()
    vim.cmd("mksession! " .. vim.fn.fnameescape(ws_dir .. name .. ".vim"))
    if reopen then tree.open() end
    vim.notify("Workspace saved: " .. name)
  end)
end, { desc = "Save named workspace" })

vim.keymap.set("n", "<leader>so", function()
  local files = vim.fn.globpath(ws_dir, "*.vim", false, true)
  if #files == 0 then vim.notify("No saved workspaces"); return end
  local names = vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ":t:r") end, files)
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(names, {
      prompt = "Workspace> ",
      actions = {
        ["default"] = function(sel)
          if sel and sel[1] then
            -- Defer past fzf teardown so the session's cd isn't reverted.
            local path = ws_dir .. sel[1] .. ".vim"
            vim.schedule(function() load_workspace(path) end)
          end
        end,
      },
    })
  else
    vim.ui.select(names, { prompt = "Load workspace:" }, function(name)
      if name then load_workspace(ws_dir .. name .. ".vim") end
    end)
  end
end, { desc = "Open named workspace" })

-- Delete a named workspace file (sx, deliberately not sD — too close a
-- shift-slip to sd/sl to make destructive).
vim.keymap.set("n", "<leader>sx", function()
  local files = vim.fn.globpath(ws_dir, "*.vim", false, true)
  if #files == 0 then vim.notify("No saved workspaces"); return end
  local names = vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ":t:r") end, files)
  local function del(name)
    if not name or name == "" then return end
    local path = ws_dir .. name .. ".vim"
    if vim.fn.delete(path) == 0 then
      vim.notify("Workspace deleted: " .. name)
    else
      vim.notify("Failed to delete workspace: " .. name, vim.log.levels.ERROR)
    end
  end
  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(names, {
      prompt = "Delete workspace> ",
      actions = { ["default"] = function(sel) if sel and sel[1] then del(sel[1]) end end },
    })
  else
    vim.ui.select(names, { prompt = "Delete workspace:" }, del)
  end
end, { desc = "Delete named workspace" })

-- =============================================================================
-- FILE MANAGEMENT — git-aware moves + LSP reference updates on rename
-- =============================================================================
-- Hooks nvim-tree's rename events so that reorganizing a repo Just Works:
--   * Before the move: ask LSP servers to rewrite import/require paths that
--     point at the file (workspace/willRenameFiles).
--   * After the move:  notify servers (workspace/didRenameFiles) and stage the
--     rename in git so `git status` shows a clean R<old> -> <new>.
-- All steps are best-effort and silently no-op when unsupported.

local ok_api, api = pcall(require, "nvim-tree.api")
if not ok_api then return end

local Event = api.events.Event

-- Capability probe that avoids version differences in client:supports_method.
local function has_cap(client, op)
  return vim.tbl_get(client, "server_capabilities", "workspace", "fileOperations", op) ~= nil
end

local function file_operation(op, old, new)
  local files = { { oldUri = vim.uri_from_fname(old), newUri = vim.uri_from_fname(new) } }
  for _, client in ipairs(vim.lsp.get_clients()) do
    if op == "willRename" and has_cap(client, "willRename") then
      local ok, resp = pcall(client.request_sync, client,
        "workspace/willRenameFiles", { files = files }, 1000, 0)
      if ok and resp and resp.result then
        vim.lsp.util.apply_workspace_edit(resp.result, client.offset_encoding)
      end
    elseif op == "didRename" and has_cap(client, "didRename") then
      pcall(client.notify, client, "workspace/didRenameFiles", { files = files })
    end
  end
end

-- Stage the rename in git so history/diffs track it as a move rather than an
-- unrelated delete + untracked add. Only acts inside a repo, only when the old
-- path was tracked, and never touches files outside the worktree.
local function git_stage_rename(old, new)
  if vim.fn.executable("git") ~= 1 or not vim.system then return end
  local dir = vim.fn.fnamemodify(old, ":h")
  local root = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }):wait()
  if root.code ~= 0 then return end
  local tracked = vim.system({ "git", "-C", dir, "ls-files", "--error-unmatch", "--", old }):wait()
  if tracked.code ~= 0 then return end
  -- Stage both endpoints; git's rename detection collapses them into an R.
  vim.system({ "git", "-C", dir, "add", "--", old, new }):wait()
end

api.events.subscribe(Event.WillRenameNode, function(data)
  file_operation("willRename", data.old_name, data.new_name)
end)

api.events.subscribe(Event.NodeRenamed, function(data)
  file_operation("didRename", data.old_name, data.new_name)
  git_stage_rename(data.old_name, data.new_name)
end)

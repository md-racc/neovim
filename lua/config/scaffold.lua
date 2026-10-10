-- =============================================================================
-- scaffold.lua — project generators for <leader>op ("New project")
-- =============================================================================
-- Generic, NOT an embedded feature — embedded is merely one entry in the
-- registry (§9). It lives in config/ (not lang/) because lang/ modules are
-- buffer-local and FileType-dispatched, and cannot contribute to an action
-- invoked when no relevant buffer exists yet.
--
-- The whole point of the bind (vs a shell alias) is the handoff: scaffold → :tcd
-- into the new root → open the entry file → let FileType dispatch and
-- embedded.detect() fire naturally on the new buffer. No scaffold-specific LSP
-- glue anywhere — the buffer-local dispatcher already does that for free (§9.3).

local M = {}

-- Remembered across invocations (session lifetime; NOT persisted to disk) so the
-- second project of a session defaults to the same parent as the first (§9.3.3).
local last_parent = nil

-- ---------------------------------------------------------------------------
-- The registry. Adding a project type = ONE table entry here, never a bind
-- (Axiom 5, enforced by construction). %s interpolates the project name.
--   name  : shown in the picker
--   run   : list of argv tables run in order — run[1] in the PARENT dir, the
--           rest in the new root. A non-zero exit aborts and notifies.
--   entry : file to open (relative to the new root) once created
--   post  : optional post(root, name) hook
--   env   : optional fun(cont) resolving an env map for every run step —
--           cont(env|nil) to proceed, or notify + don't call cont to abort.
--           ESP-IDF needs this: idf.py is not on nvim's PATH unless export.sh
--           was sourced, so reuse lang/embedded.lua's resolution (export.sh /
--           EIM activation scripts), same as every other IDF action.
-- ---------------------------------------------------------------------------
M.generators = {
  {
    name  = "C++ (CMake)",
    run   = { { "mkdir", "-p", "%s/src" } },
    entry = "src/main.cpp",
    post  = function(root, name)
      local function write(path, content)
        if vim.uv.fs_stat(path) then return end
        local f = io.open(path, "w"); if f then f:write(content); f:close() end
      end
      write(root .. "/CMakeLists.txt",
        ("cmake_minimum_required(VERSION 3.20)\nproject(%s)\n"
         .. "set(CMAKE_CXX_STANDARD 17)\n"
         .. "add_executable(%s src/main.cpp)\n"):format(name, name))
      write(root .. "/src/main.cpp",
        '#include <iostream>\n\nint main() {\n  std::cout << "Hello, World!\\n";\n}\n')
    end,
  },
  {
    name  = "ESP-IDF",
    run   = { { "idf.py", "create-project", "%s" } },
    entry = "main/%s.c",
    env   = function(cont) require("lang.embedded").idf_env(cont) end,
    post  = function(root) require("lang.embedded").reindex(root) end,
  },
  {
    name  = "Python (uv)",
    run   = { { "uv", "init", "%s" }, { "uv", "venv" } },
    entry = "main.py",
  },
  {
    name  = "Bash script",
    run   = { { "mkdir", "-p", "%s" } },
    entry = "%s.sh",
    post  = function(root, name)
      vim.fn.setfperm(root .. "/" .. name .. ".sh", "rwxr-xr-x")
    end,
  },
}

-- `name` is a REPLACEMENT string here, not literal text — gsub interprets its
-- own %-escapes in it (e.g. a project name containing "%-" or "%1" throws
-- "invalid use of '%' in replacement string"). A function replacement sidesteps
-- that entirely: whatever it returns is inserted verbatim.
local function interp(s, name) return (s:gsub("%%s", function() return name end)) end

-- Run the argv steps in order, async, aborting on the first non-zero exit with
-- a notify carrying stderr (§9.3.5). run[1] executes in `parent`, the rest in
-- the new `root`. `env` (map|nil) applies to every step. Calls on_done() only
-- if every step succeeds.
local function run_steps(steps, name, parent, root, env, on_done)
  local i = 0
  local function step()
    i = i + 1
    local s = steps[i]
    if not s then on_done(); return end
    local argv = {}
    for _, a in ipairs(s) do argv[#argv + 1] = interp(a, name) end
    -- pcall: vim.system THROWS on spawn failure (ENOENT — tool not installed);
    -- turn that into the same notify-and-abort as a non-zero exit.
    local ok, err = pcall(vim.system, argv,
      { text = true, cwd = (i == 1) and parent or root, env = env },
      function(res)
        vim.schedule(function()
          if res.code ~= 0 then
            vim.notify(("Scaffold step failed: %s\n%s")
              :format(table.concat(argv, " "), res.stderr or ""), vim.log.levels.ERROR)
            return -- abort; no :tcd, no empty buffer, editor left as-is (§9.3.5)
          end
          step()
        end)
      end)
    if not ok then
      vim.notify(("Scaffold step failed: %s\n%s")
        :format(table.concat(argv, " "), tostring(err)), vim.log.levels.ERROR)
    end
  end
  step()
end

function M.new_project()
  local names = {}
  for _, g in ipairs(M.generators) do names[#names + 1] = g.name end

  vim.ui.select(names, { prompt = "New project:" }, function(choice)
    if not choice then return end
    local gen
    for _, g in ipairs(M.generators) do if g.name == choice then gen = g; break end end
    if not gen then return end

    vim.ui.input({ prompt = "Project name: " }, function(name)
      if not name or name == "" then return end -- cancelled → abort silently

      vim.ui.input(
        { prompt = "Parent directory: ", default = last_parent or vim.fn.getcwd(), completion = "dir" },
        function(parent)
          if not parent or parent == "" then return end
          parent = vim.fn.fnamemodify(vim.fn.expand(parent), ":p"):gsub("/$", "")
          last_parent = parent
          local root = parent .. "/" .. name
          if vim.uv.fs_stat(root) then
            vim.notify("Already exists: " .. root, vim.log.levels.ERROR); return
          end

          local function go(env)
            run_steps(gen.run, name, parent, root, env, function()
              -- The payload: re-root and open the entry file so FileType dispatch
              -- + embedded.detect() fire naturally on the new buffer (§9.3.6-8).
              vim.cmd("tcd " .. vim.fn.fnameescape(root))
              local ok_tree, tree = pcall(require, "nvim-tree.api")
              if ok_tree then pcall(tree.tree.change_root, root) end
              if gen.entry then
                vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. interp(gen.entry, name)))
              end
              if gen.post then pcall(gen.post, root, name) end
              vim.notify("Created " .. gen.name .. ": " .. root)
            end)
          end
          if gen.env then gen.env(go) else go(nil) end
        end)
    end)
  end)
end

return M

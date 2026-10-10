-- =============================================================================
-- embedded.lua — ESP-IDF / STM32 / PlatformIO support for the C/C++ workflow
-- =============================================================================
-- This is a *library*, not a language module. It is require()d by lua/lang/cpp.lua
-- (which owns the <leader>l keymaps) and by lua/config/lsp.lua (clangd) and
-- lua/config/dap.lua (on-chip debug). It is NOT registered with the FileType
-- dispatcher.
--
-- Embedded is a *profile* — a target/toolchain dimension of an existing C/C++
-- buffer, selected by project detection at buffer-attach time. A host C++ buffer
-- (no profile detected) must behave EXACTLY as before; every entry point here
-- returns nil / falls through for the host case.
--
-- See ~/SPEC-embedded.md for the design. Detection is cheap and silent (§2):
-- small file reads only, no shelling out, no vim.notify. A missing toolchain
-- surfaces only when the user presses a bind that needs it.

local M = {}

-- ---------------------------------------------------------------------------
-- User-overridable constants. Set any of these before this module loads (e.g.
-- vim.g.embedded_stm32_monitor = { "picocom", "-b", "115200" }) to override.
-- ---------------------------------------------------------------------------
M.config = {
  -- Serial monitor for STM32 / bare PlatformIO fallback. `tio` is preferred
  -- (sane defaults, reconnects on re-plug); the {port} placeholder is replaced.
  stm32_monitor = vim.g.embedded_stm32_monitor or { "tio", "{port}" },
  monitor_baud  = vim.g.embedded_monitor_baud or 115200,
  -- STM32 flasher. {elf}/{port} placeholders are replaced.
  stm32_flash   = vim.g.embedded_stm32_flash
    or { "STM32_Programmer_CLI", "-c", "port=SWD", "-w", "{elf}", "-rst" },
  -- System-package ESP-IDF roots to probe for export.sh when $IDF_PATH isn't
  -- exported (e.g. Arch AUR `esp-idf` installs to /opt/esp-idf and exports
  -- nothing).
  idf_paths     = vim.g.embedded_idf_paths or { "/opt/esp-idf" },
}

-- Xtensa cores need Espressif's LLVM fork; everything else (RISC-V) uses stock
-- clangd. Anything not listed is treated as RISC-V (§3.2).
local XTENSA = {
  esp32 = true, esp32s2 = true, esp32s3 = true,
}

local function arch_of(target)
  if not target then return "riscv" end -- unknown -> riscv for LSP (§3.2)
  return XTENSA[target] and "xtensa" or "riscv"
end

-- ---------------------------------------------------------------------------
-- Small filesystem helpers (silent, cheap).
-- ---------------------------------------------------------------------------
local function exists(path) return path and vim.uv.fs_stat(path) ~= nil end

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local data = fd:read("*a")
  fd:close()
  return data
end

local function glob(pat)
  return vim.fn.glob(pat, true, true) -- {nosuf=true, list=true}
end

local function first_glob(pat)
  local m = glob(pat)
  return m[1]
end

-- Directory of the buffer, or cwd for an unnamed buffer.
local function buffer_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == "" then return vim.fn.getcwd() end
  return vim.fs.dirname(name)
end

-- =============================================================================
-- DETECTION (§2)
-- =============================================================================

-- dir -> resolved {root, kind} (or false when no project up the tree)
local root_of = {}
-- root path -> lazily-populated profile table
local profiles = {}

-- Marker predicates, tested per directory (deepest first).
local function is_esp_idf(dir)
  if exists(dir .. "/sdkconfig") or exists(dir .. "/sdkconfig.defaults") then
    return true
  end
  local cml = read_file(dir .. "/CMakeLists.txt")
  if cml and (cml:find("include%(%$ENV{IDF_PATH}", 1) or cml:find("idf_component_register", 1, true)) then
    return true
  end
  return false
end

local function is_platformio(dir)
  return exists(dir .. "/platformio.ini")
end

local function is_stm32(dir)
  if first_glob(dir .. "/*.ioc") then return true end
  if exists(dir .. "/CMakePresets.json") and first_glob(dir .. "/*arm-none-eabi*.cmake") then
    return true
  end
  local cml = read_file(dir .. "/CMakeLists.txt")
  if cml and cml:find("CMAKE_TOOLCHAIN_FILE") and cml:find("arm%-none%-eabi") then
    return true
  end
  return false
end

-- STM32: derive the OpenOCD target config name ("stm32f4x", "stm32f1x", ...)
-- from the .ioc file's MCU family. Shared by toggle_openocd below and the
-- cortex-debug config in lua/config/dap.lua — keep both in sync if this
-- changes. Conservative fallback: stm32f1x (user edits configFiles if wrong).
function M.stm32_family(root)
  local ioc = first_glob(root .. "/*.ioc")
  if ioc then
    local content = read_file(ioc)
    local fam = content and content:match("Mcu%.Family=STM32(%w+)")
    if fam then return "stm32" .. fam:sub(1, 1):lower() .. "x" end
  end
  return "stm32f1x"
end

local function parent_of(dir, home)
  if dir == home or dir == "/" then return nil end
  local parent = vim.fs.dirname(dir)
  if parent == dir then return nil end
  return parent
end

-- `idf_component_register` lives in EVERY component's CMakeLists (main/,
-- components/*/), not just the project root — so a match there means "somewhere
-- inside an IDF project", and the real root is the *topmost* ancestor holding a
-- definitive root marker: sdkconfig(.defaults) or a CMakeLists that includes
-- project.cmake. Ascend to it (opening main/main.c must root at the project,
-- where sdkconfig + CONFIG_IDF_TARGET live).
local function idf_project_root(dir, home)
  local best, cur = nil, dir
  while cur do
    if exists(cur .. "/sdkconfig") or exists(cur .. "/sdkconfig.defaults") then
      best = cur
    else
      local cml = read_file(cur .. "/CMakeLists.txt")
      if cml and cml:find("include%(%$ENV{IDF_PATH}") then best = cur end
    end
    cur = parent_of(cur, home)
  end
  return best
end

-- Walk up from `dir` (deepest first). First directory carrying any marker wins;
-- within that directory, IDF > PlatformIO > STM32 (§2 order note). Stop at $HOME
-- or /.
local function find_root(dir)
  local home = vim.uv.os_homedir() or vim.fn.expand("~")
  local cur  = dir
  while cur and cur ~= "" do
    if is_esp_idf(cur) then
      return { root = idf_project_root(cur, home) or cur, kind = "esp_idf" }
    end
    if is_platformio(cur) then return { root = cur, kind = "platformio" } end
    if is_stm32(cur)      then return { root = cur, kind = "stm32" } end
    cur = parent_of(cur, home)
  end
  return nil
end

-- Read CONFIG_IDF_TARGET from sdkconfig, falling back to sdkconfig.defaults
-- (many templates pin the target there before a real sdkconfig exists, e.g.
-- right after cloning/scaffolding a fresh Xtensa project) -> nil if neither
-- has it yet.
local function idf_target(root)
  local sdk = read_file(root .. "/sdkconfig") or read_file(root .. "/sdkconfig.defaults")
  if not sdk then return nil end
  return sdk:match('CONFIG_IDF_TARGET="([%w_]+)"')
end

-- Read IDF_TARGET out of a build dir's CMakeCache.txt (no cache -> nil).
-- Used by reindex() to catch clang_dir being stuck on a target the project
-- switched away from — reconfigure alone won't move it, only fullclean will.
local function cached_target(build_dir)
  local cache = read_file(build_dir .. "/CMakeCache.txt")
  if not cache then return nil end
  return cache:match("IDF_TARGET:[%u]+=([%w_]+)")
end

-- STM32: pick a configure preset from CMakePresets.json. Prefer "Debug", else
-- the first. Silent — lfb re-picks interactively (§5.1). Returns name or nil.
local function stm32_default_preset(root)
  local raw = read_file(root .. "/CMakePresets.json")
  if not raw then return nil end
  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then return nil end
  local names = {}
  for _, p in ipairs(data.configurePresets or {}) do
    if type(p) == "table" and p.name and not p.hidden then
      names[#names + 1] = p.name
    end
  end
  for _, n in ipairs(names) do if n == "Debug" then return "Debug" end end
  return names[1]
end

-- PlatformIO: default_envs from platformio.ini, else the first [env:NAME].
local function pio_default_env(root)
  local ini = read_file(root .. "/platformio.ini")
  if not ini then return nil end
  local def = ini:match("default_envs%s*=%s*([%w_%-,%s]+)")
  if def then return vim.trim(def:match("([%w_%-]+)") or "") end
  return ini:match("%[env:([%w_%-]+)%]")
end

-- Build the (cached) profile table for a detected root.
local function build_profile(r)
  local p = { kind = r.kind, root = r.root, port = nil }
  if r.kind == "esp_idf" then
    p.idf_path   = os.getenv("IDF_PATH")
    p.target     = idf_target(r.root)
    p.arch       = arch_of(p.target)
    p.build_dir  = r.root .. "/build"
    p.clang_dir  = r.root .. "/build.clang"
  elseif r.kind == "stm32" then
    p.preset     = stm32_default_preset(r.root)
    p.build_dir  = p.preset and (r.root .. "/build/" .. p.preset) or (r.root .. "/build")
    p.elf        = first_glob(p.build_dir .. "/*.elf")
  elseif r.kind == "platformio" then
    p.env        = pio_default_env(r.root)
    p.build_dir  = p.env and (r.root .. "/.pio/build/" .. p.env) or (r.root .. "/.pio")
  end
  return p
end

--- Detect the embedded profile for a buffer. Returns the (cached, per-root)
--- profile table, or nil for a host C++ buffer. Cheap and silent.
function M.detect(bufnr)
  local dir = buffer_dir(bufnr)
  if not dir or dir == "" then return nil end
  local r = root_of[dir]
  if r == nil then
    r = find_root(dir) or false
    root_of[dir] = r
  end
  if not r then return nil end
  local prof = profiles[r.root]
  if not prof then
    prof = build_profile(r)
    profiles[r.root] = prof
  end
  return prof
end

--- Drop cached state for a root so the next detect() re-reads sdkconfig etc.
--- Called after a target change (lfb) or a sdkconfig write.
function M.invalidate(root)
  if not root then
    root_of, profiles = {}, {}
    return
  end
  profiles[root] = nil
  for dir, r in pairs(root_of) do
    if r and r.root == root then root_of[dir] = nil end
  end
end

-- =============================================================================
-- ESP-IDF ENVIRONMENT (§3.1) — detect, do not assume export.sh vs EIM.
-- =============================================================================
-- Resolve once per root, cache the result. `env` is a map suitable for the
-- jobstart/vim.system `env` option; nil means "inherit the parent env" (the
-- user already sourced the activation before launching nvim — the preferred
-- setup). false means "no ESP-IDF found" (caller notifies and no-ops).

local INHERIT = setmetatable({}, { __tostring = function() return "<inherit>" end })

-- One-time synchronous shell-out to source an activation script and dump its
-- resulting environment (env -0). Allowed once per session (§3.1). Returns a map,
-- or nil + the script's own error text (export.sh prints actionable guidance —
-- e.g. "run install.sh" when the ~/.espressif tools are missing — and
-- swallowing it leaves a misleading "ESP-IDF not found").
local function source_env(script)
  local out = vim.system(
    { "bash", "-c", "source " .. vim.fn.shellescape(script) .. " >/dev/null 2>&1 && env -0" },
    { text = false }
  ):wait()
  if out.code == 0 and out.stdout then
    local env = {}
    for entry in tostring(out.stdout):gmatch("([^%z]+)") do
      local k, v = entry:match("^([^=]+)=(.*)$")
      if k then env[k] = v end
    end
    if next(env) then return env end
  end
  -- Failure: re-run just the source to harvest its message (error path only;
  -- export.sh prints guidance to stdout, which the env dump above discards).
  local diag = vim.system(
    { "bash", "-c", "source " .. vim.fn.shellescape(script) .. " 2>&1" },
    { text = true }
  ):wait()
  return nil, vim.trim(diag.stdout or "")
end

-- The resolved environment is per-INSTALL, not per-project: cache it module-
-- wide so profile invalidation (sdkconfig / manifest saves, set-target) never
-- forces a re-source (a synchronous ~1-2s stall), and scaffolding + every root
-- share one resolution (and one EIM choice) per session.
local envc = {} -- { env = INHERIT|map|false, choices = {...}, err = "..." }

local function resolve_idf_env()
  if envc.env ~= nil then return envc.env end -- cached (INHERIT / map / false)

  -- (1) Already exported into nvim's env — preferred path.
  if os.getenv("IDF_PATH") and os.getenv("IDF_PYTHON_ENV_PATH") then
    envc.env = INHERIT
    return envc.env
  end

  -- (2) EIM activation scripts (ESP-IDF v6+).
  local eim = glob(vim.fn.expand("~/.espressif/activate_idf_*.sh"))
  local tools = os.getenv("IDF_TOOLS_PATH")
  if tools then
    vim.list_extend(eim, glob(tools .. "/activate_idf_*.sh"))
  end
  local script
  if #eim == 1 then
    script = eim[1]
  elseif #eim > 1 then
    -- Several installs: prompt is deferred to the caller via a sentinel.
    envc.choices = eim
    -- Fall through to try export.sh; if none, caller handles the choice list.
  end

  -- (3) export.sh (ESP-IDF v5.x).
  if not script then
    local idf_path = os.getenv("IDF_PATH")
    if idf_path and exists(idf_path .. "/export.sh") then
      script = idf_path .. "/export.sh"
    end
  end

  -- (4) System package installs (Arch AUR esp-idf → /opt/esp-idf): the package
  -- exports no $IDF_PATH, so probe the well-known roots (M.config.idf_paths).
  if not script then
    for _, dir in ipairs(M.config.idf_paths) do
      if exists(dir .. "/export.sh") then
        script = dir .. "/export.sh"
        break
      end
    end
  end

  if script then
    local env, err = source_env(script)
    envc.env = env or false
    if not env then
      envc.err = "ESP-IDF: failed to source " .. script
        .. ((err and err ~= "") and ("\n" .. err) or "")
    end
    return envc.env
  end

  -- (2b) Multiple EIM scripts and nothing else: let the caller pick, don't cache.
  if envc.choices then return "choose" end

  envc.env = false
  return envc.env
end

-- =============================================================================
-- COMMAND EXECUTION HELPERS
-- =============================================================================

-- Resolve the jobstart/vim.system env option for a profile. For ESP-IDF returns
-- a map or nil (inherit); may notify + return false when IDF is unavailable, or
-- prompt when several EIM installs exist (async → calls `cont` with the env).
local function with_env(p, cont)
  if p.kind ~= "esp_idf" then cont(nil); return end
  local env = resolve_idf_env()
  if env == INHERIT then cont(nil); return end
  if env == "choose" then
    vim.ui.select(envc.choices, { prompt = "ESP-IDF activation script:" }, function(choice)
      if not choice then return end
      local e, err = source_env(choice)
      envc.env = e or false
      if not e then
        vim.notify("Failed to source " .. choice
          .. ((err and err ~= "") and ("\n" .. err) or ""), vim.log.levels.ERROR)
        return
      end
      cont(e)
    end)
    return
  end
  if env == false then
    vim.notify(envc.err
      or "ESP-IDF not found: export $IDF_PATH/$IDF_PYTHON_ENV_PATH, or install ESP-IDF (export.sh / EIM).",
      vim.log.levels.ERROR)
    return
  end
  cont(env)
end

-- Resolve `name` to an absolute path by walking `env.PATH` (falling back to
-- nvim's own PATH so a system-wide install still resolves). Needed because
-- jobstart validates argv[1] as executable against nvim's OWN PATH before
-- ever looking at the `env` option meant for the child process — unlike
-- vim.system, which honors `env.PATH` for resolution too. Any bare tool name
-- (idf.py, pio, ...) that only lives in a captured export.sh env therefore
-- has to arrive at jobstart pre-resolved to an absolute path, or it fails
-- with E475 "not executable" despite `env` carrying the right PATH.
local function resolve_exe(name, env)
  if name:sub(1, 1) == "/" then return name end -- already absolute
  local path = (env and env.PATH) or vim.env.PATH or ""
  for dir in path:gmatch("[^:]+") do
    local cand = dir .. "/" .. name
    if vim.fn.executable(cand) == 1 then return cand end
  end
  return name
end

--- Locate an executable through the profile's resolved environment — i.e. the
--- PATH captured from export.sh, which is where the xtensa/riscv esp gdbs live
--- (~/.espressif/tools). Nothing is exported into any shell; the resolved env
--- rides along so the caller can hand it to the spawned process. Async like
--- with_env; calls cont(abs_path_or_nil, env_or_nil).
function M.find_tool(p, name, cont)
  with_env(p, function(env)
    local resolved = resolve_exe(name, env)
    cont(vim.fn.executable(resolved) == 1 and resolved or nil, env)
  end)
end

--- Resolve the ESP-IDF environment with NO detected project — for
--- config/scaffold.lua, where idf.py must run before the project exists.
--- Same resolution + module-wide cache as any other IDF action. Calls
--- cont(env|nil); notifies and no-ops when no ESP-IDF install is found.
function M.idf_env(cont) with_env({ kind = "esp_idf" }, cont) end

-- Interpolate {port}/{elf}/{env} placeholders in an argv template.
local function fill(argv, subs)
  local out = {}
  for _, a in ipairs(argv) do
    out[#out + 1] = a:gsub("{(%w+)}", function(k) return subs[k] or ("{" .. k .. "}") end)
  end
  return out
end

-- One reusable terminal-split helper (none is exported from editor.lua/python.lua
-- to reuse). Runs argv in a bottom split terminal. Returns the buffer handle.
-- `env` (map|nil) is passed through; `on_exit(code)` fires when the job ends.
local function term(argv, opts)
  opts = opts or {}
  local height = opts.height or 15
  if opts.full then
    vim.cmd("tabnew")
  else
    -- `:split` (no args) reuses the CURRENT buffer, not a fresh one — the
    -- terminal would then take over e.g. the open .c buffer in place,
    -- inheriting its filetype=c. clangd then attaches to the resulting
    -- term://...  buffer too and chokes decoding its non-file:// URI ("clangd
    -- only supports 'file' URI scheme ... at (root)", repeated for every
    -- keystroke/output line). `:new` always opens a fresh, unnamed buffer.
    vim.cmd(("rightbelow %dnew"):format(height))
  end
  local buf = vim.api.nvim_get_current_buf()
  -- Resolve argv[1] against opts.env here, once, so every call site (flash,
  -- monitor, erase-flash, size, set-target, menuconfig, ...) is covered
  -- without each one having to remember find_tool() — jobstart otherwise
  -- validates the command against nvim's own PATH, not opts.env (see
  -- resolve_exe above).
  local resolved = vim.deepcopy(argv)
  resolved[1] = resolve_exe(resolved[1], opts.env)
  vim.fn.jobstart(resolved, {
    term    = true,
    cwd     = opts.cwd,
    env     = opts.env,
    on_exit = function(_, code)
      if opts.on_exit then vim.schedule(function() opts.on_exit(code) end) end
    end,
  })
  vim.cmd("startinsert")
  return buf
end

-- Run a non-interactive command, capturing stdout+stderr into `cb(result)`.
local function run_capture(argv, env, cwd, cb)
  vim.system(argv, { text = true, env = env, cwd = cwd }, function(res)
    vim.schedule(function() cb(res) end)
  end)
end

-- =============================================================================
-- SERIAL PORT SELECTION (§5.3)
-- =============================================================================

local function enumerate_ports()
  local ports = {}
  local seen  = {}
  local function add(p)
    if p ~= "" and not seen[p] then seen[p] = true; ports[#ports + 1] = p end
  end
  -- Stable by-id names first, then the raw device nodes.
  for _, p in ipairs(glob("/dev/serial/by-id/*")) do add(p) end
  for _, p in ipairs(glob("/dev/ttyUSB*")) do add(p) end
  for _, p in ipairs(glob("/dev/ttyACM*")) do add(p) end
  return ports
end

-- Resolve a port for the profile, calling cont(port). `force` re-picks even if
-- one is cached (lfp). Caches the choice on the profile.
local function resolve_port(p, force, cont)
  if p.port and not force then cont(p.port); return end
  local ports = enumerate_ports()
  if #ports == 0 then
    vim.notify("No serial ports found (/dev/serial/by-id, ttyUSB*, ttyACM*).", vim.log.levels.WARN)
    return
  end
  if #ports == 1 and not force then
    p.port = ports[1]; cont(p.port); return
  end
  vim.ui.select(ports, { prompt = "Serial port:" }, function(choice)
    if not choice then return end
    p.port = choice
    cont(choice)
  end)
end

-- =============================================================================
-- SERIAL MONITOR (§5.2) — one per root, toggled by lfm.
-- =============================================================================

local monitors = {} -- root -> { buf = , winclosed = }

local function monitor_argv(p, port)
  if p.kind == "esp_idf" then
    return { "idf.py", "-C", p.root, "-p", port, "monitor" }
  elseif p.kind == "platformio" then
    local a = { "pio", "device", "monitor" }
    if p.env then vim.list_extend(a, { "-e", p.env }) end
    vim.list_extend(a, { "--port", port })
    return a
  else -- stm32 / fallback
    if vim.fn.executable("pio") == 1 and p.kind == "platformio" then
      return { "pio", "device", "monitor", "--port", port }
    end
    return fill(M.config.stm32_monitor, { port = port })
  end
end

local function monitor_is_open(root)
  local m = monitors[root]
  return m and m.buf and vim.api.nvim_buf_is_valid(m.buf)
end

local function close_monitor(root)
  local m = monitors[root]
  if not m then return end
  if m.buf and vim.api.nvim_buf_is_valid(m.buf) then
    pcall(vim.api.nvim_buf_delete, m.buf, { force = true })
  end
  monitors[root] = nil
end

local function open_monitor(p, cont)
  resolve_port(p, false, function(port)
    with_env(p, function(env)
      local buf = term(monitor_argv(p, port), {
        env = env,
        on_exit = function() monitors[p.root] = nil end,
      })
      monitors[p.root] = { buf = buf }
      if cont then cont() end
    end)
  end)
end

function M.toggle_monitor(p)
  if monitor_is_open(p.root) then
    close_monitor(p.root)
  else
    open_monitor(p)
  end
end

-- =============================================================================
-- BUILD / RUN / ERRORS (§8) — the universal verbs, embedded backends.
-- =============================================================================

local function build_argv(p)
  if p.kind == "esp_idf" then
    return { "idf.py", "-C", p.root, "build" }
  elseif p.kind == "stm32" then
    return p.preset and { "cmake", "--build", "--preset", p.preset }
      or { "cmake", "--build", p.build_dir }
  elseif p.kind == "platformio" then
    return p.env and { "pio", "run", "-e", p.env } or { "pio", "run" }
  end
end

-- Strip ninja progress lines ([12/345]) and route GCC diagnostics to quickfix,
-- resolving paths relative to the build dir so jumps land (§8).
M._last_qf = nil
local function build_to_qf(p, lines, title)
  local cleaned = {}
  for _, l in ipairs(lines) do
    -- Ninja: "[12/345] ...". Make (common on STM32 setups without ninja):
    -- "[ 12%] Building ...".
    if not l:match("^%[%s*%d+/%d+%]") and not l:match("^%[%s*%d+%%%]") then
      cleaned[#cleaned + 1] = l
    end
  end
  vim.fn.setqflist({}, " ", {
    title = title,
    lines = cleaned,
    efm   = vim.o.errorformat,
  })
  -- Resolve relative paths against the build dir (compile_commands.json paths
  -- are relative to it, not the project root).
  local qf = vim.fn.getqflist()
  for _, item in ipairs(qf) do
    if item.bufnr and item.bufnr > 0 then
      local name = vim.api.nvim_buf_get_name(item.bufnr)
      if name ~= "" and name:sub(1, 1) ~= "/" then
        local abs = vim.fs.normalize(p.build_dir .. "/" .. name)
        if exists(abs) then
          item.filename = abs
          item.bufnr = nil
        end
      end
    end
  end
  vim.fn.setqflist({}, "r", { title = title, items = qf })
  M._last_qf = title
end

--- lb: build. Populates the quickfix and opens it only on failure (§8).
function M.build(p)
  vim.cmd("silent! wall")
  with_env(p, function(env)
    local argv = build_argv(p)
    vim.notify(table.concat(argv, " "), vim.log.levels.INFO, { title = "build" })
    run_capture(argv, env, p.root, function(res)
      local lines = vim.split((res.stdout or "") .. (res.stderr or ""), "\n", { trimempty = true })
      build_to_qf(p, lines, "build (" .. p.kind .. ")")
      if res.code ~= 0 then
        vim.cmd("copen")
        vim.notify("Build failed", vim.log.levels.ERROR)
      else
        -- STM32's p.elf is globbed once at first detect() (usually before any
        -- build exists, so nil) and never refreshed otherwise — without this,
        -- every downstream flash/erase/size/debug action keeps using a stale
        -- or nil path for the rest of the session after the first build.
        if p.kind == "stm32" then
          p.elf = first_glob(p.build_dir .. "/*.elf")
        end
        vim.notify("Build OK", vim.log.levels.INFO)
      end
    end)
  end)
end

--- le: reopen the last build's quickfix (§8, matches cpp.lua's le semantics).
function M.errors(_)
  if M._last_qf then
    vim.cmd("copen")
  else
    vim.notify("No previous build", vim.log.levels.INFO)
  end
end

-- Flash (and optionally monitor). Closes any open monitor for this root first,
-- flashes, then reopens the monitor if it was open (§5.2 — the port is held by
-- the monitor and a flash-while-monitoring fails).
local function flash_argv(p, port, with_monitor)
  if p.kind == "esp_idf" then
    local a = { "idf.py", "-C", p.root, "-p", port, "flash" }
    if with_monitor then a[#a + 1] = "monitor" end
    return a
  elseif p.kind == "platformio" then
    local a = { "pio", "run" }
    if p.env then vim.list_extend(a, { "-e", p.env }) end
    vim.list_extend(a, { "-t", "upload", "--upload-port", port })
    if with_monitor then vim.list_extend(a, { "-t", "monitor" }) end
    return a
  else -- stm32
    return fill(M.config.stm32_flash, { elf = p.elf or "", port = port })
  end
end

local function do_flash(p, port, with_monitor)
  local had_monitor = monitor_is_open(p.root)
  if had_monitor then close_monitor(p.root) end
  with_env(p, function(env)
    term(flash_argv(p, port, with_monitor), {
      env = env,
      on_exit = function()
        -- Reopen the monitor we closed (unless this flash already re-entered it).
        if had_monitor and not with_monitor and not monitor_is_open(p.root) then
          open_monitor(p)
        end
      end,
    })
  end)
end

-- Notify + return true when `name` isn't on PATH — for host tools (STM32/ARM)
-- that never go through the ESP export.sh-resolved environment.
local function stm32_tool_missing(name)
  if vim.fn.executable(name) == 1 then return false end
  vim.notify(name .. " not found", vim.log.levels.ERROR)
  return true
end

-- STM32's default flasher (STM32_Programmer_CLI over SWD) never consumes
-- {port} — only an overridden vim.g.embedded_stm32_flash pointing at a
-- port-based tool would. Requiring a serial port unconditionally otherwise
-- blocks flashing outright on a bare ST-Link setup with no USB-serial bridge.
local function stm32_flash_needs_port()
  for _, a in ipairs(M.config.stm32_flash) do
    if a:find("{port}", 1, true) then return true end
  end
  return false
end

--- lr: flash + monitor (esp_idf / platformio) or flash (stm32). Uses the cached
--- port. lR (with_prompt) forces a port re-pick first.
function M.run(p, with_prompt)
  if p.kind == "stm32" then
    if stm32_tool_missing(M.config.stm32_flash[1]) then return end
    if not stm32_flash_needs_port() then do_flash(p, nil, false); return end
  end
  resolve_port(p, with_prompt or false, function(port)
    local mon = (p.kind == "esp_idf" or p.kind == "platformio")
    do_flash(p, port, mon)
  end)
end

--- lff: flash only.
function M.flash(p)
  if p.kind == "stm32" then
    if stm32_tool_missing(M.config.stm32_flash[1]) then return end
    if not stm32_flash_needs_port() then do_flash(p, nil, false); return end
  end
  resolve_port(p, false, function(port) do_flash(p, port, false) end)
end

-- =============================================================================
-- DEVICE SUB-GROUP ACTIONS (<leader>lf*, §5.1)
-- =============================================================================

--- lfe: erase flash — guarded by a confirm naming port + chip (§5.4).
function M.erase(p)
  if p.kind == "stm32" and stm32_tool_missing("STM32_Programmer_CLI") then return end

  local function proceed(port)
    local chip = p.target or p.kind
    local prompt = port
      and ("Erase flash on %s (%s)? type 'yes': "):format(chip, port)
      or  ("Erase flash on %s? type 'yes': "):format(chip)
    vim.ui.input({ prompt = prompt }, function(ans)
      if ans ~= "yes" then vim.notify("Erase cancelled"); return end
      local had_monitor = monitor_is_open(p.root)
      if had_monitor then close_monitor(p.root) end
      with_env(p, function(env)
        local argv
        if p.kind == "esp_idf" then
          argv = { "idf.py", "-C", p.root, "-p", port, "erase-flash" }
        elseif p.kind == "platformio" then
          argv = { "pio", "run" }
          if p.env then vim.list_extend(argv, { "-e", p.env }) end
          vim.list_extend(argv, { "-t", "erase", "--upload-port", port })
        else
          argv = { "STM32_Programmer_CLI", "-c", "port=SWD", "-e", "all" }
        end
        term(argv, {
          env = env,
          on_exit = function() if had_monitor then open_monitor(p) end end,
        })
      end)
    end)
  end

  -- STM32's erase (like its flash) never uses a serial port — SWD only.
  if p.kind == "stm32" then
    proceed(nil)
  else
    resolve_port(p, false, proceed)
  end
end

--- lfp: force a port re-pick (overwrites the cache).
function M.pick_port(p)
  resolve_port(p, true, function(port) vim.notify("Port: " .. port) end)
end

--- lfb: select target / board / env.
function M.select_target(p)
  if p.kind == "esp_idf" then
    local chips = {
      "esp32", "esp32s2", "esp32s3", "esp32c2", "esp32c3",
      "esp32c5", "esp32c6", "esp32c61", "esp32h2", "esp32p4",
    }
    vim.ui.select(chips, { prompt = "Set ESP-IDF target:" }, function(chip)
      if not chip then return end
      -- Resolve to an absolute path: jobstart (unlike vim.system) validates
      -- argv[1] against nvim's OWN PATH before spawning, ignoring the `env`
      -- option for that check — so a bare "idf.py" fails with E475 whenever
      -- it's only reachable through the captured export.sh env (§3.1).
      M.find_tool(p, "idf.py", function(idf_py, env)
        if not idf_py then
          vim.notify("idf.py not found (export.sh not sourced / EIM not installed?)",
            vim.log.levels.ERROR)
          return
        end
        term({ idf_py, "-C", p.root, "set-target", chip }, {
          env = env,
          on_exit = function()
            M.invalidate(p.root)  -- target changed; sdkconfig will differ
            M.reindex(p.root)     -- different soc/ headers -> re-index (§4.1)
          end,
        })
      end)
    end)
  elseif p.kind == "stm32" then
    local raw = read_file(p.root .. "/CMakePresets.json")
    local names = {}
    if raw then
      local ok, data = pcall(vim.json.decode, raw)
      if ok and type(data) == "table" then
        for _, cp in ipairs(data.configurePresets or {}) do
          if cp.name and not cp.hidden then names[#names + 1] = cp.name end
        end
      end
    end
    if #names == 0 then vim.notify("No CMake presets found", vim.log.levels.WARN); return end
    vim.ui.select(names, { prompt = "CMake preset:" }, function(name)
      if not name then return end
      p.preset    = name
      p.build_dir = p.root .. "/build/" .. name
      p.elf       = first_glob(p.build_dir .. "/*.elf")
      vim.notify("Preset: " .. name)
    end)
  elseif p.kind == "platformio" then
    local ini = read_file(p.root .. "/platformio.ini") or ""
    local envs = {}
    for e in ini:gmatch("%[env:([%w_%-]+)%]") do envs[#envs + 1] = e end
    if #envs == 0 then vim.notify("No PlatformIO envs found", vim.log.levels.WARN); return end
    vim.ui.select(envs, { prompt = "PlatformIO env:" }, function(e)
      if not e then return end
      p.env       = e
      p.build_dir = p.root .. "/.pio/build/" .. e
      vim.notify("Env: " .. e)
    end)
  end
end

--- lfc: device config (menuconfig) — ESP-IDF only (a full-window TUI).
function M.menuconfig(p)
  if p.kind ~= "esp_idf" then
    vim.notify("menuconfig is ESP-IDF only", vim.log.levels.WARN); return
  end
  M.find_tool(p, "idf.py", function(idf_py, env)
    if not idf_py then
      vim.notify("idf.py not found (export.sh not sourced / EIM not installed?)",
        vim.log.levels.ERROR)
      return
    end
    term({ idf_py, "-C", p.root, "menuconfig" }, { env = env, full = true })
  end)
end

--- lfs: size report.
function M.size(p)
  with_env(p, function(env)
    local argv
    if p.kind == "esp_idf" then
      argv = { "idf.py", "-C", p.root, "size" }
    elseif p.kind == "platformio" then
      argv = { "pio", "run" }
      if p.env then vim.list_extend(argv, { "-e", p.env }) end
      vim.list_extend(argv, { "-t", "size" })
    else
      if stm32_tool_missing("arm-none-eabi-size") then return end
      argv = { "arm-none-eabi-size", p.elf or "" }
    end
    term(argv, { env = env })
  end)
end

--- lfo: toggle the OpenOCD GDB server (for on-chip debug, §6). ESP-IDF spawns
--- it via idf.py; STM32 via a raw openocd invocation.
M._openocd = {} -- root -> job id
function M.toggle_openocd(p)
  local job = M._openocd[p.root]
  if job then
    pcall(vim.fn.jobstop, job)
    M._openocd[p.root] = nil
    vim.notify("OpenOCD stopped")
    return
  end
  local argv
  if p.kind == "esp_idf" then
    argv = { "idf.py", "-C", p.root, "openocd" }
  else -- stm32
    if stm32_tool_missing("openocd") then return end
    argv = { "openocd", "-f", "interface/stlink.cfg", "-f", "target/" .. M.stm32_family(p.root) .. ".cfg" }
  end
  with_env(p, function(env)
    argv[1] = resolve_exe(argv[1], env) -- jobstart needs argv[1] pre-resolved (see resolve_exe)
    M._openocd[p.root] = vim.fn.jobstart(argv, {
      env = env,
      on_exit = function() M._openocd[p.root] = nil end,
    })
    vim.notify("OpenOCD started (:3333)")
  end)
end

-- =============================================================================
-- CLANGD (§4) — profile-aware argv. Consumed by lua/config/lsp.lua.
-- =============================================================================

-- The host argv, byte-identical to the pre-embedded config. NEVER diverge from
-- lua/config/lsp.lua's original list for the host case (acceptance #2).
local HOST_CLANGD = { "clangd", "--function-arg-placeholders", "--completion-style=detailed" }

-- Version dirs are dated snapshots (e.g. "esp-15.0.0_20250607"), so a lexical
-- sort orders them chronologically too — pick the newest instead of whatever
-- glob() happened to list first, which left a stale toolchain from a prior
-- ESP-IDF install arbitrarily selected.
local function esp_clang_binary()
  local matches = glob(vim.fn.expand("~/.espressif/tools/esp-clang/*/esp-clang/bin/clangd"))
  table.sort(matches)
  return matches[#matches]
end

local function arm_query_drivers()
  local drivers = {}
  for _, tool in ipairs({ "arm-none-eabi-g++", "arm-none-eabi-gcc" }) do
    if vim.fn.executable(tool) == 1 then
      drivers[#drivers + 1] = "--query-driver=" .. vim.fn.exepath(tool)
    end
  end
  -- CubeCLT glob (robust across version bumps) — g++ MUST be included or C++
  -- headers red out (§4.2).
  drivers[#drivers + 1] = "--query-driver=/opt/st/**/arm-none-eabi*"
  return drivers
end

local function pio_query_driver()
  local gpp = first_glob(vim.fn.expand("~/.platformio/packages/toolchain-*/bin/*-g++"))
    or first_glob(vim.fn.expand("~/.platformio/packages/toolchain-*/bin/*gcc"))
  if gpp then return { "--query-driver=" .. vim.fn.fnamemodify(gpp, ":h") .. "/*" } end
  return {}
end

--- Return the clangd argv for a given project root (or nil root → current
--- buffer). Host projects return HOST_CLANGD unchanged. Side-effect free.
function M.clangd_argv(root)
  local p
  if root then
    p = profiles[root]
    if not p then
      -- Not yet cached: resolve directly from the root path.
      local r = find_root(root)
      if r and r.root == root then p = build_profile(r); profiles[root] = p end
    end
  else
    p = M.detect(0)
  end
  if not p then return vim.deepcopy(HOST_CLANGD) end

  local argv = vim.deepcopy(HOST_CLANGD)
  local function add(t) vim.list_extend(argv, t) end

  if p.kind == "esp_idf" then
    -- Xtensa needs esp-clang; RISC-V uses stock clangd (§4.1).
    if p.arch == "xtensa" then
      local bin = esp_clang_binary()
      if bin then argv[1] = bin end
    end
    -- Prefer the clang-clean index build dir; fall back to the GCC build dir.
    local ccd = exists(p.clang_dir .. "/compile_commands.json") and p.clang_dir or p.build_dir
    add({ "--compile-commands-dir=" .. ccd, "--header-insertion=never" })
  elseif p.kind == "stm32" then
    add(arm_query_drivers())
    add({ "--compile-commands-dir=" .. p.build_dir, "--header-insertion=never" })
  elseif p.kind == "platformio" then
    add(pio_query_driver())
    add({ "--compile-commands-dir=" .. p.root, "--header-insertion=never" })
  end
  return argv
end

-- =============================================================================
-- RE-INDEXING (§4.1) — regenerate the clang-clean compile DB, restart clangd.
-- =============================================================================

-- Restart clangd clients rooted at/above `root` so they pick up a regenerated
-- compile DB, then re-fire FileType on loaded c/cpp buffers to re-attach.
local function restart_clangd(root)
  -- Match on attached buffers, not client.root_dir: clangd's vim.lsp.config
  -- never sets root_dir/root_markers (cmd is a function, argv computed from
  -- embedded.detect() instead), so every clangd client's root_dir is nil —
  -- `c.root_dir and ...` would always be false and no client would ever stop,
  -- silently no-opping every re-index-triggered restart (sdkconfig save,
  -- idf_component.yml save, :EspReindex, lfb target select, §4.1).
  for _, c in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    for buf in pairs(c.attached_buffers or {}) do
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.startswith(name, root .. "/") then
        pcall(function() c:stop(true) end)
        break
      end
    end
  end
  vim.schedule(function()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) then
        local ft = vim.bo[b].filetype
        if ft == "c" or ft == "cpp" then
          vim.api.nvim_buf_call(b, function()
            vim.api.nvim_exec_autocmds("FileType", { modeline = false })
          end)
        end
      end
    end
  end)
end

--- Regenerate the ESP-IDF clang index build dir (configure-only, fast) and
--- restart clangd for that root. No-op for non-IDF profiles. Silent on success
--- unless `on_ok` is given (called after clangd restarts).
function M.reindex(root, on_ok)
  local p = profiles[root]
  if not p then
    local r = find_root(root)
    if r then p = build_profile(r); profiles[r.root] = p; root = r.root end
  end
  if not p or p.kind ~= "esp_idf" then return end
  with_env(p, function(env)
    -- Prefer the clang-clean DB (§4.1). On failure (typically esp-clang not
    -- installed) fall back to a plain GCC reconfigure: it still runs the
    -- component manager (so idf_component.yml dependencies download) and
    -- refreshes the GCC compile DB that clangd_argv falls back to.
    local function reconfigure_clang()
      run_capture(
        { "idf.py", "-B", p.clang_dir, "-D", "IDF_TOOLCHAIN=clang", "reconfigure" },
        env, p.root,
        function(res)
          if res.code == 0 then
            -- Drop the cached profile before restarting: reconfigure may have
            -- just written CONFIG_IDF_TARGET (or a clang_dir compile db) for
            -- the first time, e.g. right after scaffold's create-project.
            -- Without this, clangd_argv() keeps handing out the profile
            -- snapshot taken at first buffer-attach — wrong arch, wrong
            -- compile-commands-dir — for the rest of the session.
            M.invalidate(p.root)
            restart_clangd(p.root)
            if on_ok then on_ok() end
            return
          end
          run_capture({ "idf.py", "reconfigure" }, env, p.root, function(res2)
            if res2.code ~= 0 then
              vim.notify("idf.py reconfigure failed (clang AND gcc):\n"
                .. (res2.stderr or ""), vim.log.levels.WARN)
              return
            end
            vim.notify("clang reconfigure failed (esp-clang missing?) — using the GCC DB.",
              vim.log.levels.WARN)
            M.invalidate(p.root)
            restart_clangd(p.root)
            if on_ok then on_ok() end
          end)
        end)
    end

    -- A bare `reconfigure` won't move clang_dir off a target it was already
    -- configured for (idf.py refuses: "CMakeCache.txt contains 'X'") — only
    -- `set-target` (via a full fullclean here) does. This bites right after
    -- lfb changes the target: the default build_dir gets set-target'd, but
    -- clang_dir doesn't, so it silently keeps indexing the OLD target's
    -- headers/macros until this catches the drift.
    local stale = p.target and cached_target(p.clang_dir)
    if stale and stale ~= p.target then
      run_capture({ "idf.py", "-B", p.clang_dir, "fullclean" }, env, p.root, function(res)
        if res.code ~= 0 then
          vim.notify("idf.py fullclean (clang_dir) failed:\n" .. (res.stderr or ""),
            vim.log.levels.WARN)
          return
        end
        reconfigure_clang()
      end)
    else
      reconfigure_clang()
    end
  end)
end

-- User command escape hatch (§4.1) — no keymap (hot tier is closed).
vim.api.nvim_create_user_command("EspReindex", function()
  local p = M.detect(0)
  if not p then vim.notify("Not in an embedded project", vim.log.levels.WARN); return end
  M.reindex(p.root)
end, { desc = "Regenerate the ESP-IDF clang index + restart clangd" })

-- Manifest-driven config changes re-index automatically (debounced, async):
--   * sdkconfig — a Kconfig change (menuconfig / edit) can add or remove whole
--     components from the include path (§4.1). Silent on success.
--   * idf_component.yml — the IDF component manager's dependency manifest
--     (PlatformIO-style lib_deps UX): save it and the reconfigure inside
--     reindex pulls the declared components into managed_components/, then
--     clangd restarts so the new headers resolve immediately. The next lb
--     build reconfigures itself off the changed manifest, so nothing else is
--     needed on the build side.
-- Keyed by root: a single shared timer would let a save in project B cancel
-- project A's still-pending reindex outright (two ESP-IDF projects open in
-- the same session), silently leaving A never re-indexed.
local reindex_timers = {}
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "sdkconfig", "idf_component.yml" },
  callback = function(args)
    local p = M.detect(args.buf)
    if not p or p.kind ~= "esp_idf" then return end
    local root = p.root
    M.invalidate(root)
    local manifest = args.file:match("idf_component%.yml$") ~= nil
    if manifest then
      vim.notify("Resolving IDF components…", vim.log.levels.INFO)
    end
    if reindex_timers[root] then reindex_timers[root]:stop() end
    reindex_timers[root] = vim.defer_fn(function()
      reindex_timers[root] = nil
      M.reindex(root, manifest and function()
        vim.notify("IDF components resolved", vim.log.levels.INFO)
      end or nil)
    end, 500)
  end,
})

-- PlatformIO gets the symmetric treatment for its own manifest: pio resolves
-- lib_deps natively at build time, but clangd doesn't see new packages until
-- compile_commands.json is regenerated. Saving platformio.ini runs
-- `pio run -t compiledb` (which resolves packages first) into the project
-- root — exactly where clangd_argv points --compile-commands-dir for pio —
-- then restarts clangd.
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "platformio.ini",
  callback = function(args)
    local p = M.detect(args.buf)
    if not p or p.kind ~= "platformio" then return end
    M.invalidate(p.root) -- env list / default_envs may have changed
    vim.notify("Resolving PlatformIO packages…", vim.log.levels.INFO)
    run_capture({ "pio", "run", "-t", "compiledb" }, nil, p.root, function(res)
      if res.code ~= 0 then
        vim.notify("pio compiledb failed:\n" .. (res.stderr or ""), vim.log.levels.WARN)
        return
      end
      restart_clangd(p.root)
      vim.notify("PlatformIO packages resolved", vim.log.levels.INFO)
    end)
  end,
})

return M

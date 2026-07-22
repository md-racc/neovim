-- =============================================================================
-- C / C++  (+C++)
-- =============================================================================
-- Universal verb contract: lb build/check, lr run, lR run w/ args, le errors,
-- lc/lC callers/callees, lt type hierarchy. C++ extras: lh header/source switch,
-- ld yank definition stub, l3/l5 rule of 3/5, and the lm* CMake sub-group.

-- ---------------------------------------------------------------------------
-- Header/source switch, landing on the *counterpart of the function under the
-- cursor* rather than the top of the file (moved here from config/lsp.lua):
--   * in a .cpp, cursor in a definition  -> its declaration (header prototype)
--   * in a .h,   cursor on a declaration -> its definition  (the .cpp body)
-- clangd resolves definition<->declaration, so we point it at the function name
-- and ask for the opposite. Not on a function -> plain file toggle.
-- ---------------------------------------------------------------------------
-- Embedded (ESP-IDF / STM32 / PlatformIO) is a profile *inside* C++ — the same
-- filetype, a different toolchain, selected by project detection at attach time.
-- The universal verbs below branch on the detected profile; a host C++ buffer
-- (embedded.detect -> nil) always falls through to the original g++/CMake paths,
-- byte-for-byte unchanged.
local embedded = require("lang.embedded")

local SRC_EXT = { c = true, cc = true, cpp = true, cxx = true, ["c++"] = true }
local FN_CONTAINER = {
  function_definition = true,
  field_declaration   = true,
  declaration         = true,
}

local function fn_name_node()
  -- Force the "cpp" grammar: .h headers often get filetype "c" (a
  -- filetype-derived parser would mis-parse a C++ class), and cpp is a superset
  -- that parses C declarations too.
  local ok, parser = pcall(vim.treesitter.get_parser, 0, "cpp")
  if not ok or not parser then return nil end
  parser:parse()
  local cur  = vim.api.nvim_win_get_cursor(0)
  local node = parser:named_node_for_range({ cur[1] - 1, cur[2], cur[1] - 1, cur[2] })

  while node and not FN_CONTAINER[node:type()] do node = node:parent() end
  local d = node and node:field("declarator")[1]
  while d and d:type() ~= "function_declarator" do d = d:field("declarator")[1] end
  local id = d and d:field("declarator")[1]
  while id and id:type() == "qualified_identifier" do id = id:field("name")[1] end
  return id
end

local function switch_source_header()
  local id = fn_name_node()
  if not id then
    vim.cmd("ClangdSwitchSourceHeader") -- not on a function: plain file toggle
    return
  end
  local srow, scol = id:start()
  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  if SRC_EXT[vim.fn.expand("%:e")] then
    vim.lsp.buf.declaration()
  else
    vim.lsp.buf.definition()
  end
end

-- ---------------------------------------------------------------------------
-- Compile helpers (all .cpp in the current file's directory, C++17 -Wall).
-- ---------------------------------------------------------------------------
local function srcdir() return vim.fn.expand("%:p:h") end

-- lb: compile → binary named after the current file, beside the source.
local function build()
  vim.cmd("w")
  local dir = srcdir()
  local out = vim.fn.shellescape(dir .. "/" .. vim.fn.expand("%:t:r"))
  vim.cmd("rightbelow 15split | terminal g++ -std=c++17 -Wall -o " .. out
    .. " " .. vim.fn.shellescape(dir) .. "/*.cpp")
end

-- lr / lR: compile → a per-instance scratch binary and run (optionally with
-- prompted argv). tempname() lives in this nvim's private tempdir (removed on
-- exit), so parallel instances — same project, different branches — can't
-- clobber each other's binary the way a shared /tmp/cpp_out did.
local run_out = vim.fn.tempname() .. "_cpp_out"
local function run(with_args)
  vim.cmd("w")
  local dir  = vim.fn.shellescape(srcdir())
  local out  = vim.fn.shellescape(run_out)
  local base = "g++ -std=c++17 -Wall -o " .. out .. " " .. dir .. "/*.cpp && " .. out
  local function go(argv)
    local cmd = base .. (argv and argv ~= "" and (" " .. argv) or "")
    vim.cmd("rightbelow 15split | terminal " .. cmd)
  end
  if with_args then
    vim.ui.input({ prompt = "Program args: " }, function(a) if a ~= nil then go(a) end end)
  else
    go(nil)
  end
end

-- le: syntax-check all .cpp and route diagnostics to the quickfix list.
local function errors()
  vim.cmd("w")
  local dir   = vim.fn.shellescape(srcdir())
  local lines = vim.fn.systemlist("g++ -std=c++17 -Wall -fsyntax-only " .. dir .. "/*.cpp 2>&1")
  vim.fn.setqflist({}, " ", { title = "g++", lines = lines, efm = vim.o.errorformat })
  vim.cmd("copen")
end

-- Universal verbs, profile-aware. The host branch calls the original functions
-- unchanged (acceptance criterion #1: zero regressions on the plain g++ path).
local function vb() local p = embedded.detect(0); if p then embedded.build(p) else build() end end
local function vr(a) return function() local p = embedded.detect(0); if p then embedded.run(p, a) else run(a) end end end
local function ve() local p = embedded.detect(0); if p then embedded.errors(p) else errors() end end

-- A <leader>lf* device action: only ever invoked in an embedded buffer (the
-- dispatcher filters these out of host buffers), but guard defensively anyway.
local function dev(fn) return function() local p = embedded.detect(0); if p then fn(p) end end end

-- Per-buffer registration filter (see lua/lang/init.lua). Keeps `maps` a static
-- superset for the docs generator while registering only what fits the buffer's
-- profile:
--   * lf* (device sub-group): only in embedded projects, minus keys a profile
--     lacks (STM32 has no menuconfig; PlatformIO has no menuconfig/openocd).
--   * lm* (CMake sub-group): host + STM32 only; ESP-IDF and PlatformIO own their
--     own build system, so a raw cmake --build there is wrong (§3.4, §7).
local LF_OMIT = {
  esp_idf    = {},
  stm32      = { lfc = true },
  platformio = { lfc = true, lfo = true },
}
local function filter(buf, lhs)
  local p    = embedded.detect(buf)
  local kind = p and p.kind
  if lhs:sub(1, 2) == "lf" and #lhs >= 3 then
    if not kind then return false end
    return not (LF_OMIT[kind] or {})[lhs]
  end
  if lhs:sub(1, 2) == "lm" then
    return kind == nil or kind == "stm32"
  end
  return true
end

return {
  name   = "C++",
  groups = {
    { "lm", "CMake",        icon = 0xF08EA },
    { "lf", "Flash/Device", icon = 0xF0E1B },
  },
  filter = filter,
  maps   = {
    -- Universal verbs (host: g++/CMake — embedded: idf.py/cmake/pio)
    { "lb", vb,        desc = "Build" },
    { "lr", vr(false), desc = "Run / flash" },
    { "lR", vr(true),  desc = "Run / flash (prompt args / port)" },
    { "le", ve,        desc = "Build errors -> quickfix" },
    { "lc", vim.lsp.buf.incoming_calls, desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls, desc = "Call hierarchy: callees" },
    { "lt", vim.lsp.buf.typehierarchy,  desc = "Type hierarchy" },
    -- C++ extras
    { "lh", switch_source_header,  desc = "Header/source switch (counterpart)" },
    { "ld", "<cmd>TSCppYankImpl<cr>", desc = "Yank definition stub" },
    { "ld", ":TSCppYankImpl<cr>",  desc = "Yank definition stubs (selection)", mode = "x" },
    { "l3", "<cmd>TSCppRuleOf3<cr>", desc = "Generate rule of 3" },
    { "l5", "<cmd>TSCppRuleOf5<cr>", desc = "Generate rule of 5" },
    -- CMake sub-group (build-system verbs, distinct from the raw-g++ verbs).
    -- Hidden in ESP-IDF / PlatformIO buffers by `filter`.
    { "lmb", "<cmd>CMakeBuild<cr>",              desc = "CMake build" },
    { "lmr", "<cmd>CMakeRun<cr>",                desc = "CMake run" },
    { "lmd", "<cmd>CMakeDebug<cr>",              desc = "CMake debug" },
    { "lms", "<cmd>CMakeSelectBuildType<cr>",    desc = "CMake select build type" },
    { "lmt", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "CMake select target" },
    -- Flash / Device sub-group (depth-3, embedded-only). Registered by `filter`
    -- only when a profile is detected; absent in host C++ buffers (acceptance #1).
    { "lff", dev(embedded.flash),          desc = "Flash" },
    { "lfm", dev(embedded.toggle_monitor), desc = "Toggle serial monitor" },
    { "lfe", dev(embedded.erase),          desc = "Erase flash" },
    { "lfp", dev(embedded.pick_port),      desc = "Select serial port" },
    { "lfb", dev(embedded.select_target),  desc = "Select target / board" },
    { "lfc", dev(embedded.menuconfig),     desc = "Device config (menuconfig)" },
    { "lfs", dev(embedded.size),           desc = "Size report" },
    { "lfo", dev(embedded.toggle_openocd), desc = "Toggle OpenOCD server" },
  },
}

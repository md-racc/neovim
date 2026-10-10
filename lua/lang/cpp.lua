-- =============================================================================
-- C / C++  (+C++)
-- =============================================================================
-- Universal verb contract: lb build/check, lr run, lR run w/ args, le errors,
-- lc/lC callers/callees, lt type hierarchy. C++ extras: lh header/source switch,
-- ld yank definition stub, l3/l5 rule of 3/5.

-- ---------------------------------------------------------------------------
-- Header/source switch, landing on the *counterpart of the function under the
-- cursor* rather than the top of the file (moved here from config/lsp.lua):
--   * in a .cpp, cursor in a definition  -> its declaration (header prototype)
--   * in a .h,   cursor on a declaration -> its definition  (the .cpp body)
-- clangd resolves definition<->declaration, so we point it at the function name
-- and ask for the opposite. Not on a function -> plain file toggle.

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

return {
  name   = "C++",
  maps   = {
    -- Universal verbs (g++ / CMake)
    { "lb", build,      desc = "Build" },
    { "lr", function() run(false) end, desc = "Run" },
    { "lR", function() run(true) end,  desc = "Run (prompt args)" },
    { "le", errors,     desc = "Build errors -> quickfix" },
    { "lc", vim.lsp.buf.incoming_calls, desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls, desc = "Call hierarchy: callees" },
    { "lt", function() vim.lsp.buf.typehierarchy("subtypes") end,
      desc = "Type hierarchy: subtypes" },
    { "lT", function() vim.lsp.buf.typehierarchy("supertypes") end,
      desc = "Type hierarchy: supertypes" },
    -- C++ extras
    { "lh", switch_source_header,  desc = "Header/source switch (counterpart)" },
    { "ld", "<cmd>TSCppYankImpl<cr>", desc = "Yank definition stub" },
    { "ld", ":TSCppYankImpl<cr>",  desc = "Yank definition stubs (selection)", mode = "x" },
    { "l3", "<cmd>TSCppRuleOf3<cr>", desc = "Generate rule of 3" },
    { "l5", "<cmd>TSCppRuleOf5<cr>", desc = "Generate rule of 5" },
  },
}

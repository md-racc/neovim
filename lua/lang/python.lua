-- =============================================================================
-- Python  (+Python)
-- =============================================================================
-- Universal verbs: lb typecheck, lr run, lR run w/ args, le last output, lx send
-- to REPL, lc/lC/lt call/type hierarchy. Python extras: lp IPython REPL, lv
-- select venv (+ restart LSP), li organize imports, lf ruff fix-all.

local M = {}

-- The interpreter every run/REPL uses; lv swaps it (and the LSP). Stored global
-- so it survives buffer switches within the session.
local function interp() return vim.g.python_interpreter or "python" end

-- Terminal split that remembers its buffer so a follow-up action can reopen it.
local function term_split(cmd, height)
  vim.cmd(("rightbelow %dsplit | terminal %s"):format(height or 15, cmd))
  return vim.api.nvim_get_current_buf()
end

-- lb: typecheck to quickfix (mypy if present, else ruff check) ------------------
function M.typecheck()
  vim.cmd("w")
  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  local cmd
  if vim.fn.executable("mypy") == 1 then
    cmd = "mypy --show-column-numbers " .. file
  elseif vim.fn.executable("ruff") == 1 then
    cmd = "ruff check --output-format concise " .. file
  else
    vim.notify("Neither mypy nor ruff found", vim.log.levels.WARN); return
  end
  local lines = vim.fn.systemlist(cmd .. " 2>&1")
  vim.fn.setqflist({}, " ", { title = "typecheck", lines = lines, efm = "%f:%l:%c: %m,%f:%l: %m" })
  vim.cmd("copen")
end

-- lr / lR: run the current file with the active interpreter ---------------------
M._last_output = nil
function M.run(with_args)
  vim.cmd("w")
  local file = vim.fn.shellescape(vim.fn.expand("%:p"))
  local function go(argv)
    local cmd = interp() .. " " .. file .. (argv and argv ~= "" and (" " .. argv) or "")
    M._last_output = term_split(cmd)
  end
  if with_args then
    vim.ui.input({ prompt = "Program args: " }, function(a) if a ~= nil then go(a) end end)
  else
    go(nil)
  end
end

-- le: reopen the last run's output buffer --------------------------------------
function M.last_output()
  if M._last_output and vim.api.nvim_buf_is_valid(M._last_output) then
    vim.cmd("rightbelow 15split")
    vim.api.nvim_win_set_buf(0, M._last_output)
  else
    vim.notify("No previous run output", vim.log.levels.INFO)
  end
end

-- lp / lx: an IPython (fallback: python) REPL split you can send code to --------
M._repl_buf, M._repl_chan = nil, nil
local function repl_alive() return M._repl_buf and vim.api.nvim_buf_is_valid(M._repl_buf) end

function M.toggle_repl()
  if repl_alive() then
    -- Visible -> hide the window; hidden -> reshow the same terminal buffer.
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == M._repl_buf then
        vim.api.nvim_win_close(w, false); return
      end
    end
    vim.cmd("rightbelow vsplit")
    vim.api.nvim_win_set_buf(0, M._repl_buf)
    return
  end
  local cmd = vim.fn.executable("ipython") == 1 and "ipython" or interp()
  vim.cmd("rightbelow vsplit | terminal " .. cmd)
  M._repl_buf  = vim.api.nvim_get_current_buf()
  M._repl_chan = vim.b.terminal_job_id
end

function M.send_repl(mode)
  if not repl_alive() then M.toggle_repl() end
  local lines
  if mode == "v" then
    -- Yank the visual selection to a scratch register and read it back.
    vim.cmd('noautocmd normal! "vy')
    lines = vim.split(vim.fn.getreg("v"), "\n", { plain = true })
  else
    lines = { vim.api.nvim_get_current_line() }
  end
  if M._repl_chan then
    vim.fn.chansend(M._repl_chan, table.concat(lines, "\n") .. "\n")
  end
end

-- lv: select a venv interpreter and restart the LSP pointed at it ---------------
-- The most common Python-in-nvim failure is the LSP resolving against the system
-- interpreter and reporting phantom import errors, so this must restart the
-- server, not just set a variable.
local function py_server()
  return vim.fn.executable("basedpyright") == 1 and "basedpyright" or "pyright"
end

local function apply_interpreter(pyexec)
  vim.g.python_interpreter = pyexec
  local venv = vim.fn.fnamemodify(pyexec, ":h:h") -- .../venv
  local server = py_server()
  -- Stop existing python clients, re-point the config at the venv, re-attach.
  for _, c in ipairs(vim.lsp.get_clients({ name = server })) do
    pcall(function() c:stop() end)
  end
  vim.lsp.config(server, {
    settings = {
      python = {
        pythonPath = pyexec,
        venvPath   = vim.fn.fnamemodify(venv, ":h"),
        venv       = vim.fn.fnamemodify(venv, ":t"),
      },
    },
  })
  vim.lsp.enable(server)
  -- Re-trigger LSP attach on the current python buffers. `:edit` throws E37 on
  -- unsaved changes, which previously aborted this whole callback silently —
  -- the LSP was re-pointed but neither the reload nor the confirmation notify
  -- ever ran, and the user saw a bare E37 instead.
  vim.schedule(function()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].modified then
      vim.notify("Interpreter set to " .. pyexec
        .. " — save the buffer to re-attach the LSP on it", vim.log.levels.WARN)
      return
    end
    vim.cmd("edit")
    vim.notify("Interpreter: " .. pyexec)
  end)
end

function M.select_venv()
  local cwd = vim.fn.getcwd()
  local seen, candidates = {}, {}
  local function add(p)
    p = vim.fn.fnamemodify(p, ":p")
    if vim.fn.executable(p) == 1 and not seen[p] then
      seen[p] = true; candidates[#candidates + 1] = p
    end
  end
  for _, d in ipairs({ "venv", ".venv", "env", ".env" }) do
    add(cwd .. "/" .. d .. "/bin/python")
  end
  -- One level deeper: any */bin/python under cwd (fd is available in this setup).
  if vim.fn.executable("fd") == 1 then
    for _, p in ipairs(vim.fn.systemlist(
      "fd --max-depth 3 --type f --full-path '/bin/python$' " .. vim.fn.shellescape(cwd) .. " 2>/dev/null")) do
      add(p)
    end
  end
  for _, sys in ipairs({ "python3", "python" }) do
    if vim.fn.executable(sys) == 1 then add(vim.fn.exepath(sys)) end
  end
  if #candidates == 0 then vim.notify("No interpreters found", vim.log.levels.WARN); return end

  local ok, fzf = pcall(require, "fzf-lua")
  if ok then
    fzf.fzf_exec(candidates, {
      prompt  = "Interpreter> ",
      actions = { ["default"] = function(sel) if sel[1] then apply_interpreter(sel[1]) end end },
      winopts = { title = " Select venv / interpreter " },
    })
  else
    vim.ui.select(candidates, { prompt = "Interpreter:" }, function(sel)
      if sel then apply_interpreter(sel) end
    end)
  end
end

return {
  name = "Python",
  maps = {
    { "lb", M.typecheck,               desc = "Typecheck -> quickfix" },
    { "lr", function() M.run(false) end, desc = "Run file" },
    { "lR", function() M.run(true) end,  desc = "Run with args" },
    { "le", M.last_output,             desc = "Last run output" },
    { "lx", function() M.send_repl("n") end, desc = "Send line to REPL" },
    { "lx", function() M.send_repl("v") end, desc = "Send selection to REPL", mode = "x" },
    { "lp", M.toggle_repl,             desc = "Toggle IPython REPL" },
    { "lv", M.select_venv,             desc = "Select venv (restart LSP)" },
    { "li", function() vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true }) end,
      desc = "Organize imports" },
    { "lf", function() vim.lsp.buf.code_action({ context = { only = { "source.fixAll" } }, apply = true }) end,
      desc = "Ruff fix-all" },
    { "lc", vim.lsp.buf.incoming_calls, desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls, desc = "Call hierarchy: callees" },
    { "lt", function() vim.lsp.buf.typehierarchy("subtypes") end,
      desc = "Type hierarchy: subtypes" },
    { "lT", function() vim.lsp.buf.typehierarchy("supertypes") end,
      desc = "Type hierarchy: supertypes" },
  },
}

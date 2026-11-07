-- =============================================================================
-- Rust  (+Rust)
-- =============================================================================
-- lb cargo check -> quickfix, lr / lR cargo run, lc/lC call hierarchy
-- (rust-analyzer). Commands run from the cargo workspace root.

local function root()
  local crate = vim.fs.root(0, { "Cargo.toml" }) or vim.fn.expand("%:p:h")
  -- cargo prints paths relative to the *workspace* root, which may sit above
  -- the nearest Cargo.toml (a member crate).
  local out = vim.fn.systemlist({ "cargo", "locate-project", "--workspace",
    "--message-format", "plain", "--manifest-path", crate .. "/Cargo.toml" })
  if vim.v.shell_error == 0 and out[1] then return vim.fn.fnamemodify(out[1], ":h") end
  return crate
end

-- Parse cargo's --message-format short lines (`file:line:col: level: msg`),
-- anchoring relative paths at the workspace root.
local function to_qf(lines, dir)
  local items = {}
  for _, l in ipairs(lines) do
    local f, ln, col, msg = l:match("^(.-%.rs):(%d+):(%d+): (.*)$")
    if f then
      if f:sub(1, 1) ~= "/" then f = vim.fs.normalize(dir .. "/" .. f) end
      local kind = msg:match("^(%a+)") or ""
      items[#items + 1] = {
        filename = f, lnum = tonumber(ln), col = tonumber(col), text = msg,
        type = kind == "error" and "E" or kind == "warning" and "W" or "",
      }
    elseif l:match("^error") then
      items[#items + 1] = { text = l }
    end
  end
  vim.fn.setqflist({}, " ", { title = "cargo check", items = items })
  vim.cmd("copen")
end

local function check()
  vim.cmd("update")
  if vim.fn.executable("cargo") ~= 1 then
    vim.notify("cargo not found", vim.log.levels.WARN); return
  end
  local dir   = root()
  local lines = vim.fn.systemlist("cd " .. vim.fn.shellescape(dir)
    .. " && cargo check --all-targets --message-format short 2>&1")
  to_qf(lines, dir)
end

local function run(with_args)
  vim.cmd("update")
  local function go(argv)
    vim.cmd("rightbelow 15split | terminal cd " .. vim.fn.shellescape(root()) .. " && cargo run"
      .. (argv and argv ~= "" and (" -- " .. argv) or ""))
  end
  if with_args then
    vim.ui.input({ prompt = "Program args: " }, function(a) if a ~= nil then go(a) end end)
  else
    go(nil)
  end
end

return {
  name = "Rust",
  maps = {
    { "lb", check,                      desc = "cargo check -> quickfix" },
    { "lr", function() run(false) end,  desc = "cargo run" },
    { "lR", function() run(true) end,   desc = "cargo run with args" },
    { "lc", vim.lsp.buf.incoming_calls, desc = "Call hierarchy: callers" },
    { "lC", vim.lsp.buf.outgoing_calls, desc = "Call hierarchy: callees" },
  },
}

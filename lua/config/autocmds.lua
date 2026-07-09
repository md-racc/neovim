-- =============================================================================
-- STARTUP
-- =============================================================================

-- Snap viewport to left border whenever the cursor is close enough that
-- column 0 would be visible — prevents the window staying scrolled right
-- after navigating back from a long line.
vim.api.nvim_create_autocmd("CursorMoved", {
  group = vim.api.nvim_create_augroup("SnapToLeft", { clear = true }),
  callback = function()
    local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if info.leftcol > 0 and vim.fn.virtcol(".") <= info.width then
      local view = vim.fn.winsaveview()
      view.leftcol = 0
      vim.fn.winrestview(view)
    end
  end,
})

-- Flash the yanked region briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Re-equalize splits whenever the terminal is resized (toggleable via <leader>R)
local auto_resize = true
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("AutoResize", { clear = true }),
  callback = function() if auto_resize then vim.cmd("wincmd =") end end,
})
vim.keymap.set("n", "<leader>R", function()
  auto_resize = not auto_resize
  vim.notify("Auto-resize " .. (auto_resize and "enabled" or "disabled"))
end, { desc = "Toggle auto-resize splits" })

-- When a real file is opened, wipe any leftover empty unnamed buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.fn.buflisted(buf) == 1
        and vim.api.nvim_buf_get_name(buf) == ""
        and not vim.api.nvim_get_option_value("modified", { buf = buf })
        and buf ~= vim.api.nvim_get_current_buf()
      then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end,
})

-- =============================================================================
-- MARKDOWN
-- =============================================================================

vim.api.nvim_create_autocmd("FileType", {
  pattern  = "markdown",
  callback = function()
    vim.opt_local.textwidth    = 0
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true
    vim.opt_local.breakindent  = true
    vim.opt_local.conceallevel = 2
  end,
})

-- =============================================================================
-- C / C++
-- =============================================================================

vim.api.nvim_create_autocmd("FileType", {
  pattern  = { "c", "cpp" },
  callback = function(args)
    local buf = args.buf
    local o   = function(desc) return { buffer = buf, desc = desc } end

    -- Compile to /tmp/cpp_out and run (all .cpp files in directory)
    vim.keymap.set("n", "<leader>cr", function()
      vim.cmd("w")
      local dir = vim.fn.shellescape(vim.fn.expand("%:p:h"))
      vim.cmd("rightbelow 15split | terminal g++ -std=c++17 -Wall -o /tmp/cpp_out " .. dir .. "/*.cpp && /tmp/cpp_out")
    end, o("Compile and run"))

    -- Compile to same directory as source (all .cpp files in directory)
    vim.keymap.set("n", "<leader>cc", function()
      vim.cmd("w")
      local dir = vim.fn.expand("%:p:h")
      local out = vim.fn.shellescape(dir .. "/" .. vim.fn.expand("%:t:r"))
      vim.cmd("rightbelow 15split | terminal g++ -std=c++17 -Wall -o " .. out .. " " .. vim.fn.shellescape(dir) .. "/*.cpp")
    end, o("Compile"))

    local ok_wk, wk = pcall(require, "which-key")
    if ok_wk then
      wk.add({
        { "<leader>c", group = "c++",   buffer = buf },
        { "<leader>m", group = "cmake", buffer = buf },
      })
    end
  end,
})

-- Format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern  = { "*.c", "*.cpp", "*.h", "*.hpp" },
  callback = function()
    local ok, conform = pcall(require, "conform")
    if ok then conform.format({ lsp_fallback = true }) end
  end,
})

-- =============================================================================
-- TEX
-- =============================================================================

vim.api.nvim_create_autocmd("FileType", {
  pattern  = "tex",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell        = true
    vim.opt_local.wrap         = true
    vim.opt_local.linebreak    = true

    local ok_wk, which_key = pcall(require, "which-key")
    if ok_wk then
      which_key.add({ { "<leader>l", group = "LaTeX", icon = "" } })
    end

    if vim.fn.executable("latexmk") == 0 then
      vim.ui.select({ "Yes", "No" }, { prompt = "TeXLive not installed. Install for compile?" }, function(c)
        if c == "Yes" then
          vim.cmd("!sudo pacman -S --noconfirm texlive-bin texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra texlive-science")
        end
      end)
    end
  end,
})

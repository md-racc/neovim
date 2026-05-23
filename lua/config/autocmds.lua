-- =============================================================================
-- STARTUP
-- =============================================================================

-- Flash the yanked region briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

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

    -- Compile to /tmp/cpp_out and run
    vim.keymap.set("n", "<leader>cr", function()
      vim.cmd("w")
      local src = vim.fn.shellescape(vim.fn.expand("%:p"))
      vim.cmd("rightbelow 15split | terminal g++ -std=c++17 -Wall -o /tmp/cpp_out " .. src .. " && /tmp/cpp_out")
    end, o("Compile and run"))

    -- Compile to same directory as source
    vim.keymap.set("n", "<leader>cc", function()
      vim.cmd("w")
      local out = vim.fn.shellescape(vim.fn.expand("%:p:r"))
      local src = vim.fn.shellescape(vim.fn.expand("%:p"))
      vim.cmd("rightbelow 15split | terminal g++ -std=c++17 -Wall -o " .. out .. " " .. src)
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
  end,
})

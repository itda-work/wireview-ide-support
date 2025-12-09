-- Prevent loading twice
if vim.g.loaded_wireview then
  return
end
vim.g.loaded_wireview = true

-- Check Neovim version
if vim.fn.has("nvim-0.9.0") ~= 1 then
  vim.api.nvim_err_writeln("wireview.nvim requires Neovim >= 0.9.0")
  return
end

-- Lazy load on FileType
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "htmldjango", "html" },
  once = true,
  callback = function()
    -- Plugin will be initialized when setup() is called by the user
    -- This autocmd ensures the module is available when needed
  end,
  desc = "Wireview lazy load trigger",
})

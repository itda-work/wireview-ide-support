---@mod wireview Neovim plugin for django-wireview
---@brief [[
---Provides IDE support for django-wireview components:
---- Autocompletion for components, attributes, handlers, events, modifiers
---- Go-to-definition for components and handlers
---- Hover documentation
---- Telescope integration
---@brief ]]

local M = {}

---@type boolean
local is_initialized = false

---Setup wireview plugin
---@param opts? WireviewConfig User configuration
function M.setup(opts)
  if is_initialized then
    return
  end

  -- Load configuration
  local config = require("wireview.config")
  config.setup(opts)

  -- Create user commands
  M.create_commands()

  -- Setup autocommands
  M.setup_autocommands()

  -- Register nvim-cmp source if enabled and available
  if config.get("enable_completion") then
    M.setup_completion()
  end

  -- Setup keymaps
  M.setup_keymaps()

  -- Setup Telescope extension
  M.setup_telescope()

  -- Setup which-key integration
  M.setup_whichkey()

  is_initialized = true

  -- Auto refresh metadata on startup
  if config.get("auto_refresh") then
    vim.schedule(function()
      M.refresh()
    end)
  end
end

---Create user commands
function M.create_commands()
  vim.api.nvim_create_user_command("WireviewStatus", function()
    M.status()
  end, { desc = "Show wireview plugin status" })

  vim.api.nvim_create_user_command("WireviewRefresh", function()
    M.refresh()
  end, { desc = "Refresh wireview metadata" })

  vim.api.nvim_create_user_command("WireviewGotoDefinition", function()
    M.goto_definition()
  end, { desc = "Go to wireview component/handler definition" })

  vim.api.nvim_create_user_command("WireviewHover", function()
    M.show_hover()
  end, { desc = "Show wireview hover documentation" })
end

---Setup autocommands
function M.setup_autocommands()
  local config = require("wireview.config")
  local group = vim.api.nvim_create_augroup("Wireview", { clear = true })

  -- Refresh metadata on Python file save
  if config.get("refresh_on_save") then
    local refresh_timer = nil

    vim.api.nvim_create_autocmd("BufWritePost", {
      group = group,
      pattern = "*.py",
      callback = function()
        -- Debounce refresh calls
        if refresh_timer then
          vim.fn.timer_stop(refresh_timer)
        end
        refresh_timer = vim.fn.timer_start(1000, function()
          M.refresh()
          refresh_timer = nil
        end)
      end,
      desc = "Refresh wireview metadata on Python file save",
    })
  end

  -- Setup filetype-specific keymaps
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "htmldjango", "html" },
    callback = function(event)
      M.setup_buffer_keymaps(event.buf)
    end,
    desc = "Setup wireview keymaps for Django templates",
  })
end

---Setup nvim-cmp completion source
function M.setup_completion()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    if require("wireview.config").get("debug") then
      vim.notify("[wireview] nvim-cmp not found, completion disabled", vim.log.levels.DEBUG)
    end
    return
  end

  local completion = require("wireview.completion")
  cmp.register_source("wireview", completion.new())
end

---Setup global keymaps
function M.setup_keymaps()
  -- Global keymaps can be added here if needed
end

---Setup Telescope extension
function M.setup_telescope()
  local ok = pcall(require, "telescope")
  if not ok then
    if require("wireview.config").get("debug") then
      vim.notify("[wireview] telescope.nvim not found, telescope integration disabled", vim.log.levels.DEBUG)
    end
    return
  end

  -- Setup telescope commands
  local telescope_module = require("wireview.telescope")
  telescope_module.setup()
end

---Setup which-key integration
function M.setup_whichkey()
  local ok = pcall(require, "which-key")
  if not ok then
    if require("wireview.config").get("debug") then
      vim.notify("[wireview] which-key.nvim not found, which-key integration disabled", vim.log.levels.DEBUG)
    end
    return
  end

  local whichkey = require("wireview.whichkey")
  whichkey.setup()
end

---Setup buffer-local keymaps for Django templates
---@param bufnr number Buffer number
function M.setup_buffer_keymaps(bufnr)
  local config = require("wireview.config")
  local opts = { buffer = bufnr, silent = true }

  if config.get("enable_definition") then
    vim.keymap.set("n", "gd", function()
      M.goto_definition()
    end, vim.tbl_extend("force", opts, { desc = "Wireview: Go to definition" }))
  end

  if config.get("enable_hover") then
    vim.keymap.set("n", "K", function()
      M.show_hover()
    end, vim.tbl_extend("force", opts, { desc = "Wireview: Show hover" }))
  end
end

---Show plugin status
function M.status()
  local config = require("wireview.config")
  local metadata = require("wireview.metadata")

  local lines = {
    "Wireview Status",
    "===============",
    "",
    "Configuration:",
    string.format("  Python path: %s", config.get("python_path")),
    string.format("  Django settings: %s", config.get("django_settings") or "(not set)"),
    string.format("  Metadata path: %s", config.get("metadata_path")),
    string.format("  Auto refresh: %s", config.get("auto_refresh") and "enabled" or "disabled"),
    string.format("  Refresh on save: %s", config.get("refresh_on_save") and "enabled" or "disabled"),
    string.format("  Cache TTL: %ds", config.get("cache_ttl")),
    "",
    "Features:",
    string.format("  Completion: %s", config.get("enable_completion") and "enabled" or "disabled"),
    string.format("  Hover: %s", config.get("enable_hover") and "enabled" or "disabled"),
    string.format("  Definition: %s", config.get("enable_definition") and "enabled" or "disabled"),
    "",
    "Metadata:",
  }

  if metadata.is_loaded() then
    local components = metadata.get_all_components()
    local modifiers = metadata.get_modifiers()
    table.insert(lines, string.format("  Status: loaded"))
    table.insert(lines, string.format("  Components: %d", vim.tbl_count(components)))
    table.insert(lines, string.format("  Modifiers: %d", vim.tbl_count(modifiers)))
    table.insert(lines, string.format("  Generated at: %s", metadata.get_generated_at() or "unknown"))
  else
    table.insert(lines, "  Status: not loaded")
    table.insert(lines, "  Run :WireviewRefresh to load metadata")
  end

  vim.api.nvim_echo({ { table.concat(lines, "\n"), "Normal" } }, true, {})
end

---Refresh metadata from Python
function M.refresh()
  local metadata = require("wireview.metadata")
  metadata.refresh(function(success)
    if success then
      vim.notify("[wireview] Metadata refreshed", vim.log.levels.INFO)
    else
      vim.notify("[wireview] Failed to refresh metadata", vim.log.levels.ERROR)
    end
  end)
end

---Go to definition
function M.goto_definition()
  local definition = require("wireview.definition")
  definition.goto_definition()
end

---Show hover documentation
function M.show_hover()
  local hover = require("wireview.hover")
  hover.show_hover()
end

---Get metadata (for external use)
---@return WireviewMetadata|nil
function M.get_metadata()
  local metadata = require("wireview.metadata")
  return metadata.get()
end

---Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return is_initialized
end

return M

---@class WireviewConfig
---@field python_path string Path to Python executable
---@field django_settings string Django settings module (optional)
---@field metadata_path string Path to metadata JSON file
---@field auto_refresh boolean Auto refresh metadata on startup
---@field refresh_on_save boolean Refresh metadata when Python files are saved
---@field cache_ttl number Cache TTL in seconds
---@field enable_completion boolean Enable nvim-cmp completion
---@field enable_hover boolean Enable hover documentation
---@field enable_definition boolean Enable go-to-definition
---@field debug boolean Enable debug logging

local M = {}

---@type WireviewConfig
M.defaults = {
  python_path = "python",
  django_settings = "",
  metadata_path = ".wireview/metadata.json",
  auto_refresh = true,
  refresh_on_save = true,
  cache_ttl = 300, -- 5 minutes
  enable_completion = true,
  enable_hover = true,
  enable_definition = true,
  debug = false,
}

---@type WireviewConfig
M.options = {}

---Setup configuration
---@param opts? WireviewConfig User configuration
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
  M.validate()
end

---Validate configuration
function M.validate()
  local opts = M.options

  vim.validate({
    python_path = { opts.python_path, "string" },
    django_settings = { opts.django_settings, "string" },
    metadata_path = { opts.metadata_path, "string" },
    auto_refresh = { opts.auto_refresh, "boolean" },
    refresh_on_save = { opts.refresh_on_save, "boolean" },
    cache_ttl = { opts.cache_ttl, "number" },
    enable_completion = { opts.enable_completion, "boolean" },
    enable_hover = { opts.enable_hover, "boolean" },
    enable_definition = { opts.enable_definition, "boolean" },
    debug = { opts.debug, "boolean" },
  })
end

---Get configuration value
---@param key string Configuration key
---@return any
function M.get(key)
  return M.options[key]
end

---Check if configuration is initialized
---@return boolean
function M.is_setup()
  return next(M.options) ~= nil
end

return M

---@mod wireview.metadata Metadata management for wireview
---@brief [[
---Handles loading, caching, and querying of wireview component metadata.
---Metadata is extracted from Django project using the wireview_lsp command.
---@brief ]]

local M = {}

local utils = require("wireview.utils")

---@class ParameterInfo
---@field type string|nil Parameter type annotation
---@field default any Default value
---@field has_default boolean Whether parameter has default
---@field kind string Parameter kind

---@class FieldInfo
---@field type string Python type name
---@field annotation string|nil Full type annotation
---@field default any Default value
---@field required boolean Whether field is required
---@field description string|nil Field description

---@class MethodInfo
---@field is_async boolean Whether method is async
---@field parameters table<string, ParameterInfo> Method parameters
---@field docstring string|nil Method docstring
---@field line_number number Line number in source file

---@class SlotInfo
---@field required boolean Whether slot is required
---@field doc string Slot documentation

---@class ModifierInfo
---@field docstring string|nil Modifier docstring
---@field description string Modifier description
---@field has_argument boolean Whether modifier requires argument

---@class ComponentMetadata
---@field name string Component class name
---@field fqn string Fully qualified name (module.ClassName)
---@field app_key string App-prefixed name (app:ClassName)
---@field module string Python module path
---@field file_path string Absolute file path
---@field line_number number Line number of class definition
---@field docstring string|nil Component docstring
---@field template_name string Template file name
---@field fields table<string, FieldInfo> Component fields
---@field methods table<string, MethodInfo> Component methods
---@field slots table<string, SlotInfo> Component slots
---@field subscriptions string[] Channel subscriptions
---@field subscriptions_is_dynamic boolean Whether subscriptions is dynamic
---@field temporary_assigns string[] Temporary assigns

---@class WireviewMetadata
---@field version string Metadata version
---@field generated_at string ISO 8601 timestamp
---@field components table<string, ComponentMetadata> All components
---@field modifiers table<string, ModifierInfo> Event modifiers

---@type WireviewMetadata|nil
local cached_metadata = nil

---@type boolean
local is_refreshing = false

---Load metadata from cache file
---@return boolean Success
function M.load()
  local path = utils.get_metadata_path()
  utils.log("Loading metadata from: " .. path)

  local data = utils.read_json(path)
  if not data then
    utils.log("Failed to load metadata", vim.log.levels.WARN)
    return false
  end

  -- Validate basic structure
  if not data.version or not data.components then
    utils.log("Invalid metadata structure", vim.log.levels.ERROR)
    return false
  end

  cached_metadata = data
  utils.log(
    string.format(
      "Loaded metadata: %d components, %d modifiers",
      vim.tbl_count(data.components or {}),
      vim.tbl_count(data.modifiers or {})
    )
  )

  return true
end

---Refresh metadata by running Python extractor
---@param callback? fun(success: boolean) Callback when done
function M.refresh(callback)
  if is_refreshing then
    utils.log("Refresh already in progress", vim.log.levels.DEBUG)
    if callback then
      callback(false)
    end
    return
  end

  local config = require("wireview.config")

  -- First try to load from cache
  if M.load() then
    local ttl = config.get("cache_ttl")
    if cached_metadata and utils.is_cache_valid(cached_metadata.generated_at, ttl) then
      utils.log("Using cached metadata (within TTL)")
      if callback then
        callback(true)
      end
      return
    end
  end

  -- Run Python extractor
  local manage_py = utils.find_manage_py()
  if not manage_py then
    utils.log("manage.py not found, cannot refresh metadata", vim.log.levels.ERROR)
    if callback then
      callback(false)
    end
    return
  end

  local output_path = utils.get_metadata_path()
  local output_dir = vim.fn.fnamemodify(output_path, ":h")
  utils.ensure_dir(output_dir)

  local cmd = {
    config.get("python_path"),
    manage_py,
    "wireview_lsp",
    "--output",
    output_path,
  }

  local django_settings = config.get("django_settings")
  if django_settings and django_settings ~= "" then
    table.insert(cmd, "--settings")
    table.insert(cmd, django_settings)
  end

  utils.log("Running: " .. table.concat(cmd, " "))

  is_refreshing = true
  local stderr_output = {}

  vim.fn.jobstart(cmd, {
    cwd = utils.get_workspace_root(),
    env = django_settings ~= "" and { DJANGO_SETTINGS_MODULE = django_settings } or nil,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_output, line)
          end
        end
      end
    end,
    on_exit = function(_, code)
      is_refreshing = false

      if code == 0 then
        local success = M.load()
        utils.log("Metadata refresh " .. (success and "succeeded" or "failed"))
        if callback then
          callback(success)
        end
      else
        local error_msg = table.concat(stderr_output, "\n")
        utils.log("Python extractor failed: " .. error_msg, vim.log.levels.ERROR)
        if callback then
          callback(false)
        end
      end
    end,
  })
end

---Check if metadata is loaded
---@return boolean
function M.is_loaded()
  return cached_metadata ~= nil
end

---Get raw metadata
---@return WireviewMetadata|nil
function M.get()
  return cached_metadata
end

---Get generated_at timestamp
---@return string|nil
function M.get_generated_at()
  if cached_metadata then
    return cached_metadata.generated_at
  end
  return nil
end

---Get all components
---@return table<string, ComponentMetadata>
function M.get_all_components()
  if cached_metadata and cached_metadata.components then
    return cached_metadata.components
  end
  return {}
end

---Get all modifiers
---@return table<string, ModifierInfo>
function M.get_modifiers()
  if cached_metadata and cached_metadata.modifiers then
    return cached_metadata.modifiers
  end
  return {}
end

---Find component by name, FQN, or app_key
---@param name string Component name to find
---@return ComponentMetadata|nil
function M.get_component(name)
  if not cached_metadata or not cached_metadata.components then
    return nil
  end

  -- Direct lookup by name
  if cached_metadata.components[name] then
    return cached_metadata.components[name]
  end

  -- Search by FQN or app_key
  for _, component in pairs(cached_metadata.components) do
    if component.fqn == name or component.app_key == name then
      return component
    end
  end

  return nil
end

---Get component names matching prefix
---@param prefix string Prefix to match
---@return ComponentMetadata[] Matching components
function M.find_components_by_prefix(prefix)
  local results = {}
  local lower_prefix = prefix:lower()

  for name, component in pairs(M.get_all_components()) do
    if name:lower():sub(1, #lower_prefix) == lower_prefix then
      table.insert(results, component)
    elseif component.fqn:lower():sub(1, #lower_prefix) == lower_prefix then
      table.insert(results, component)
    elseif component.app_key:lower():sub(1, #lower_prefix) == lower_prefix then
      table.insert(results, component)
    end
  end

  return results
end

---Get modifier by name
---@param name string Modifier name
---@return ModifierInfo|nil
function M.get_modifier(name)
  local modifiers = M.get_modifiers()
  return modifiers[name]
end

---Get async methods (event handlers) for a component
---@param component_name string Component name
---@return table<string, MethodInfo> Async methods only
function M.get_async_methods(component_name)
  local component = M.get_component(component_name)
  if not component or not component.methods then
    return {}
  end

  local async_methods = {}
  for name, method in pairs(component.methods) do
    if method.is_async then
      async_methods[name] = method
    end
  end

  return async_methods
end

---Get fields for a component
---@param component_name string Component name
---@return table<string, FieldInfo>
function M.get_fields(component_name)
  local component = M.get_component(component_name)
  if not component or not component.fields then
    return {}
  end
  return component.fields
end

---Get slots for a component
---@param component_name string Component name
---@return table<string, SlotInfo>
function M.get_slots(component_name)
  local component = M.get_component(component_name)
  if not component or not component.slots then
    return {}
  end
  return component.slots
end

---Clear cached metadata
function M.clear()
  cached_metadata = nil
end

return M

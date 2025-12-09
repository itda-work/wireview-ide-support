---@mod wireview.completion nvim-cmp completion source for wireview
---@brief [[
---Provides autocompletion for wireview components, attributes, handlers,
---events, modifiers, and slots.
---@brief ]]

local M = {}

local parser = require("wireview.parser")
local metadata = require("wireview.metadata")

---Methods to exclude from handler completions (base class methods)
local EXCLUDED_METHODS = {
  -- Component base methods
  "joined",
  "leaving",
  "notification",
  "mutation",
  "params_changed",
  "handle_hook_event",
  "broadcast",
  "deffer",
  "destroy",
  "focus_on",
  "skip_render",
  "force_render",
  "freeze",
  "dom",
  "stream",
  "stream_insert",
  "stream_delete",
  "assign_async",
  "allow_upload",
  "cancel_upload",
  "consume_uploads",
  -- Pydantic methods
  "model_copy",
  "model_dump",
  "model_dump_json",
  "model_json_schema",
  "model_parametrized_name",
  "model_post_init",
  "model_rebuild",
  "model_validate",
  "model_validate_json",
  "model_validate_strings",
  "model_construct",
  "copy",
  "dict",
  "json",
  "parse_obj",
  "parse_raw",
  "parse_file",
  "from_orm",
  "construct",
  "new",
}

---DOM events for completion
local DOM_EVENTS = {
  "click",
  "dblclick",
  "mousedown",
  "mouseup",
  "mouseover",
  "mouseout",
  "mousemove",
  "mouseenter",
  "mouseleave",
  "input",
  "change",
  "submit",
  "keydown",
  "keyup",
  "keypress",
  "focus",
  "blur",
  "scroll",
  "load",
  "error",
  "resize",
  "contextmenu",
  "drag",
  "dragstart",
  "dragend",
  "dragover",
  "dragenter",
  "dragleave",
  "drop",
  "touchstart",
  "touchend",
  "touchmove",
  "touchcancel",
}

---Check if method should be excluded
---@param method_name string
---@return boolean
local function is_excluded_method(method_name)
  for _, excluded in ipairs(EXCLUDED_METHODS) do
    if method_name == excluded then
      return true
    end
  end
  return false
end

---Build component documentation
---@param component ComponentMetadata
---@return string
local function build_component_doc(component)
  local lines = {}

  table.insert(lines, "## " .. component.name)
  table.insert(lines, "")
  table.insert(lines, "`" .. component.fqn .. "`")
  table.insert(lines, "")

  if component.docstring and component.docstring ~= "" then
    table.insert(lines, component.docstring)
    table.insert(lines, "")
  end

  if component.template_name then
    table.insert(lines, "**Template:** `" .. component.template_name .. "`")
    table.insert(lines, "")
  end

  -- Fields
  if component.fields and next(component.fields) then
    table.insert(lines, "**Fields:**")
    for name, field in pairs(component.fields) do
      local field_line = "- `" .. name .. "`: " .. (field.type or "any")
      if field.default ~= nil and field.default ~= vim.NIL then
        field_line = field_line .. " = " .. tostring(field.default)
      end
      if field.required then
        field_line = field_line .. " (required)"
      end
      table.insert(lines, field_line)
    end
    table.insert(lines, "")
  end

  -- Event handlers (async methods)
  local async_methods = {}
  if component.methods then
    for name, method in pairs(component.methods) do
      if method.is_async and not is_excluded_method(name) then
        async_methods[name] = method
      end
    end
  end

  if next(async_methods) then
    table.insert(lines, "**Event Handlers:**")
    for name, method in pairs(async_methods) do
      local params = {}
      if method.parameters then
        for param_name, param_info in pairs(method.parameters) do
          local param_str = param_name
          if param_info.type then
            param_str = param_str .. ": " .. param_info.type
          end
          if param_info.has_default and param_info.default ~= nil then
            param_str = param_str .. " = " .. tostring(param_info.default)
          end
          table.insert(params, param_str)
        end
      end
      table.insert(lines, "- `" .. name .. "(" .. table.concat(params, ", ") .. ")`")
    end
    table.insert(lines, "")
  end

  -- Slots
  if component.slots and next(component.slots) then
    table.insert(lines, "**Slots:**")
    for name, slot in pairs(component.slots) do
      local slot_line = "- `" .. name .. "`"
      if slot.required then
        slot_line = slot_line .. " (required)"
      end
      if slot.doc and slot.doc ~= "" then
        slot_line = slot_line .. ": " .. slot.doc
      end
      table.insert(lines, slot_line)
    end
  end

  return table.concat(lines, "\n")
end

---Build field documentation
---@param name string Field name
---@param field FieldInfo
---@return string
local function build_field_doc(name, field)
  local lines = {}

  table.insert(lines, "```python")
  local decl = name .. ": " .. (field.type or "any")
  if field.default ~= nil and field.default ~= vim.NIL then
    decl = decl .. " = " .. tostring(field.default)
  end
  table.insert(lines, decl)
  table.insert(lines, "```")

  if field.required then
    table.insert(lines, "")
    table.insert(lines, "**Required**")
  end

  if field.description and field.description ~= "" then
    table.insert(lines, "")
    table.insert(lines, field.description)
  end

  return table.concat(lines, "\n")
end

---Build method documentation
---@param name string Method name
---@param method MethodInfo
---@return string
local function build_method_doc(name, method)
  local lines = {}

  local params = {}
  if method.parameters then
    for param_name, param_info in pairs(method.parameters) do
      local param_str = param_name
      if param_info.type then
        param_str = param_str .. ": " .. param_info.type
      end
      if param_info.has_default and param_info.default ~= nil then
        param_str = param_str .. " = " .. tostring(param_info.default)
      end
      table.insert(params, param_str)
    end
  end

  table.insert(lines, "```python")
  table.insert(lines, "async def " .. name .. "(" .. table.concat(params, ", ") .. ")")
  table.insert(lines, "```")

  if method.docstring and method.docstring ~= "" then
    table.insert(lines, "")
    table.insert(lines, method.docstring)
  end

  return table.concat(lines, "\n")
end

---Build modifier documentation
---@param name string Modifier name
---@param modifier ModifierInfo
---@return string
local function build_modifier_doc(name, modifier)
  local lines = {}

  table.insert(lines, "**" .. name .. "**")
  table.insert(lines, "")
  table.insert(lines, modifier.description or "")

  if modifier.has_argument then
    table.insert(lines, "")
    table.insert(lines, "*Requires an argument (e.g., `" .. name .. ".300`)*")
  end

  return table.concat(lines, "\n")
end

---Get component completions
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_component_completions(prefix)
  local items = {}
  local components = metadata.get_all_components()
  local lower_prefix = (prefix or ""):lower()

  for name, component in pairs(components) do
    -- Filter by prefix
    local matches = lower_prefix == ""
      or name:lower():sub(1, #lower_prefix) == lower_prefix
      or component.fqn:lower():sub(1, #lower_prefix) == lower_prefix
      or component.app_key:lower():sub(1, #lower_prefix) == lower_prefix

    if matches then
      -- Simple name completion
      table.insert(items, {
        label = name,
        kind = 7, -- Class
        detail = component.fqn,
        documentation = {
          kind = "markdown",
          value = build_component_doc(component),
        },
        sortText = "0" .. name,
      })

      -- FQN completion
      table.insert(items, {
        label = component.fqn,
        kind = 7, -- Class
        detail = "Fully qualified name",
        documentation = {
          kind = "markdown",
          value = build_component_doc(component),
        },
        sortText = "1" .. component.fqn,
      })

      -- App key completion
      table.insert(items, {
        label = component.app_key,
        kind = 7, -- Class
        detail = "App-prefixed name",
        documentation = {
          kind = "markdown",
          value = build_component_doc(component),
        },
        sortText = "2" .. component.app_key,
      })
    end
  end

  return items
end

---Get attribute completions for a component
---@param component_name string
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_attribute_completions(component_name, prefix)
  local items = {}
  local fields = metadata.get_fields(component_name)
  local lower_prefix = (prefix or ""):lower()

  for name, field in pairs(fields) do
    if lower_prefix == "" or name:lower():sub(1, #lower_prefix) == lower_prefix then
      local detail = field.type or "any"
      if field.required then
        detail = detail .. " (required)"
      end

      table.insert(items, {
        label = name,
        kind = 10, -- Property
        detail = detail,
        documentation = {
          kind = "markdown",
          value = build_field_doc(name, field),
        },
        insertText = name .. "=",
        sortText = field.required and "0" .. name or "1" .. name,
      })
    end
  end

  return items
end

---Get handler completions for a component
---@param component_name string
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_handler_completions(component_name, prefix)
  local items = {}
  local async_methods = metadata.get_async_methods(component_name)
  local lower_prefix = (prefix or ""):lower()

  for name, method in pairs(async_methods) do
    if not is_excluded_method(name) then
      if lower_prefix == "" or name:lower():sub(1, #lower_prefix) == lower_prefix then
        local params = {}
        if method.parameters then
          for param_name, _ in pairs(method.parameters) do
            table.insert(params, param_name)
          end
        end

        table.insert(items, {
          label = name,
          kind = 2, -- Method
          detail = "async (" .. table.concat(params, ", ") .. ")",
          documentation = {
            kind = "markdown",
            value = build_method_doc(name, method),
          },
          sortText = "0" .. name,
        })
      end
    end
  end

  return items
end

---Get event name completions
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_event_completions(prefix)
  local items = {}
  local lower_prefix = (prefix or ""):lower()

  for _, event in ipairs(DOM_EVENTS) do
    if lower_prefix == "" or event:sub(1, #lower_prefix) == lower_prefix then
      table.insert(items, {
        label = event,
        kind = 23, -- Event
        detail = "DOM event",
        sortText = "0" .. event,
      })
    end
  end

  return items
end

---Get modifier completions
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_modifier_completions(prefix)
  local items = {}
  local modifiers = metadata.get_modifiers()
  local lower_prefix = (prefix or ""):lower()

  for name, modifier in pairs(modifiers) do
    -- Skip internal modifiers
    if not name:match("^_") then
      if lower_prefix == "" or name:lower():sub(1, #lower_prefix) == lower_prefix then
        local insert_text = name
        if modifier.has_argument then
          insert_text = name .. ".$1"
        end

        table.insert(items, {
          label = name,
          kind = 14, -- Keyword
          detail = modifier.description,
          documentation = {
            kind = "markdown",
            value = build_modifier_doc(name, modifier),
          },
          insertText = insert_text,
          insertTextFormat = modifier.has_argument and 2 or 1, -- Snippet or PlainText
          sortText = "0" .. name,
        })
      end
    end
  end

  return items
end

---Get slot completions for a component
---@param component_name string
---@param prefix string|nil Prefix to filter
---@return table[] Completion items
local function get_slot_completions(component_name, prefix)
  local items = {}
  local slots = metadata.get_slots(component_name)
  local lower_prefix = (prefix or ""):lower()

  for name, slot in pairs(slots) do
    if lower_prefix == "" or name:lower():sub(1, #lower_prefix) == lower_prefix then
      local detail = slot.required and "required slot" or "optional slot"

      table.insert(items, {
        label = name,
        kind = 5, -- Field
        detail = detail,
        documentation = slot.doc or "",
        sortText = slot.required and "0" .. name or "1" .. name,
      })
    end
  end

  return items
end

---nvim-cmp source

local source = {}

---Create new source instance
function source.new()
  return setmetatable({}, { __index = source })
end

---Get debug name
function source:get_debug_name()
  return "wireview"
end

---Check if source is available
function source:is_available()
  local ft = vim.bo.filetype
  if not parser.is_supported_filetype(ft) then
    return false
  end
  return metadata.is_loaded()
end

---Get trigger characters
function source:get_trigger_characters()
  return { "'", '"', " ", "." }
end

---Get keyword pattern
function source:get_keyword_pattern()
  return [[\k\+]]
end

---Complete
---@param params table
---@param callback function
function source:complete(params, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  local context = parser.get_cursor_context(bufnr, row, col)

  local items = {}

  if context.position == "component_name" then
    items = get_component_completions(context.current_value)
  elseif context.position == "attribute_name" then
    if context.component_name then
      items = get_attribute_completions(context.component_name, context.current_value)
    end
  elseif context.position == "attribute_value" then
    -- Could add value completions for specific attribute types
    items = {}
  elseif context.position == "handler_name" then
    if context.component_name then
      items = get_handler_completions(context.component_name, context.current_value)
    end
  elseif context.position == "event_name" then
    items = get_event_completions(context.current_value)
  elseif context.position == "modifier" then
    items = get_modifier_completions(context.current_value)
  elseif context.position == "slot_name" then
    if context.component_name then
      items = get_slot_completions(context.component_name, context.current_value)
    end
  end

  callback({ items = items, isIncomplete = false })
end

---Resolve completion item
---@param item table
---@param callback function
function source:resolve(item, callback)
  callback(item)
end

-- Export functions for module use
M.new = source.new
M.get_component_completions = get_component_completions
M.get_attribute_completions = get_attribute_completions
M.get_handler_completions = get_handler_completions
M.get_event_completions = get_event_completions
M.get_modifier_completions = get_modifier_completions
M.get_slot_completions = get_slot_completions

return M

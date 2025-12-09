---@mod wireview.hover Hover documentation for wireview
---@brief [[
---Provides hover information in floating windows for wireview components,
---handlers, attributes, and modifiers.
---@brief ]]

local M = {}

local parser = require("wireview.parser")
local metadata = require("wireview.metadata")
local utils = require("wireview.utils")

---Methods to exclude from display
local EXCLUDED_METHODS = {
  "joined", "leaving", "notification", "mutation", "params_changed",
  "handle_hook_event", "broadcast", "deffer", "destroy", "focus_on",
  "skip_render", "force_render", "freeze", "dom", "stream",
  "stream_insert", "stream_delete", "assign_async", "allow_upload",
  "cancel_upload", "consume_uploads",
  "model_copy", "model_dump", "model_dump_json", "model_json_schema",
  "model_parametrized_name", "model_post_init", "model_rebuild",
  "model_validate", "model_validate_json", "model_validate_strings",
  "model_construct", "copy", "dict", "json", "parse_obj", "parse_raw",
  "parse_file", "from_orm", "construct", "new",
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

---Build component hover content
---@param component ComponentMetadata
---@return string[]
local function build_component_hover(component)
  local lines = {}

  table.insert(lines, "## " .. component.name)
  table.insert(lines, "")
  table.insert(lines, "`" .. component.fqn .. "`")
  table.insert(lines, "")

  if component.docstring and component.docstring ~= "" then
    table.insert(lines, component.docstring)
    table.insert(lines, "")
  end

  if component.template_name and component.template_name ~= "" then
    table.insert(lines, "**Template:** `" .. component.template_name .. "`")
    table.insert(lines, "")
  end

  -- Fields section
  if component.fields and next(component.fields) then
    table.insert(lines, "### Fields")
    table.insert(lines, "")
    for name, field in pairs(component.fields) do
      local field_line = "- `" .. name .. "`: " .. (field.type or "any")
      if field.default ~= nil and field.default ~= vim.NIL then
        field_line = field_line .. " = `" .. tostring(field.default) .. "`"
      end
      if field.required then
        field_line = field_line .. " *(required)*"
      end
      table.insert(lines, field_line)
    end
    table.insert(lines, "")
  end

  -- Event handlers section
  local async_methods = {}
  if component.methods then
    for name, method in pairs(component.methods) do
      if method.is_async and not is_excluded_method(name) then
        async_methods[name] = method
      end
    end
  end

  if next(async_methods) then
    table.insert(lines, "### Event Handlers")
    table.insert(lines, "")
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

  -- Slots section
  if component.slots and next(component.slots) then
    table.insert(lines, "### Slots")
    table.insert(lines, "")
    for name, slot in pairs(component.slots) do
      local slot_line = "- `" .. name .. "`"
      if slot.required then
        slot_line = slot_line .. " *(required)*"
      end
      if slot.doc and slot.doc ~= "" then
        slot_line = slot_line .. ": " .. slot.doc
      end
      table.insert(lines, slot_line)
    end
    table.insert(lines, "")
  end

  -- Subscriptions section
  if component.subscriptions and #component.subscriptions > 0 then
    table.insert(lines, "### Subscriptions")
    table.insert(lines, "")
    for _, sub in ipairs(component.subscriptions) do
      table.insert(lines, "- `" .. sub .. "`")
    end
    if component.subscriptions_is_dynamic then
      table.insert(lines, "")
      table.insert(lines, "*Subscriptions are dynamic*")
    end
    table.insert(lines, "")
  end

  return lines
end

---Build handler hover content
---@param method_name string
---@param method MethodInfo
---@return string[]
local function build_handler_hover(method_name, method)
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
  table.insert(lines, "async def " .. method_name .. "(" .. table.concat(params, ", ") .. ")")
  table.insert(lines, "```")

  if method.docstring and method.docstring ~= "" then
    table.insert(lines, "")
    table.insert(lines, method.docstring)
  end

  return lines
end

---Build attribute hover content
---@param attr_name string
---@param field FieldInfo
---@return string[]
local function build_attribute_hover(attr_name, field)
  local lines = {}

  table.insert(lines, "```python")
  local decl = attr_name .. ": " .. (field.type or "any")
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

  return lines
end

---Build modifier hover content
---@param modifier_name string
---@param modifier ModifierInfo
---@return string[]
local function build_modifier_hover(modifier_name, modifier)
  local lines = {}

  table.insert(lines, "**" .. modifier_name .. "**")
  table.insert(lines, "")
  table.insert(lines, modifier.description or modifier.docstring or "")

  if modifier.has_argument then
    table.insert(lines, "")
    table.insert(lines, "*Requires an argument (e.g., `" .. modifier_name .. ".300`)*")
  end

  return lines
end

---Extract target under cursor
---@param content string Buffer content
---@param offset number Cursor offset
---@return string|nil target_name
---@return string|nil target_type
---@return string|nil component_name
local function extract_target(content, offset)
  -- Find {% ... %} containing cursor
  local tag_start = nil
  local tag_content = nil

  local search_pos = 1
  while true do
    local s, e = content:find("{%%.-%%}", search_pos)
    if not s then
      break
    end

    if s <= offset + 1 and e >= offset + 1 then
      tag_start = s
      tag_content = content:sub(s, e)
      break
    end

    search_pos = e + 1
  end

  if not tag_content then
    return nil, nil, nil
  end

  local cursor_in_tag = offset - tag_start + 2

  -- Component tag
  local comp_name = tag_content:match("{%%%-?%s*component[_block]*%s+['\"]([^'\"]+)['\"]")
  if comp_name then
    local name_start = tag_content:find(comp_name, 1, true)
    if name_start and cursor_in_tag >= name_start and cursor_in_tag <= name_start + #comp_name then
      return comp_name, "component", nil
    end

    -- Check for attribute
    local before_cursor = tag_content:sub(1, cursor_in_tag)
    local attr_name = before_cursor:match("(%w+)%s*=") or before_cursor:match("(%w+)$")
    if attr_name then
      return attr_name, "attribute", comp_name
    end
  end

  -- On tag
  local event_name = tag_content:match("{%%%-?%s*on%s+['\"]([^'\"%.]+)")
  if event_name then
    local handler_name = tag_content:match("{%%%-?%s*on%s+['\"][^'\"]+['\"]%s+['\"]([^'\"]+)['\"]")

    -- Check if on event name
    local event_start = tag_content:find(event_name, 1, true)
    if event_start and cursor_in_tag >= event_start and cursor_in_tag <= event_start + #event_name then
      return event_name, "event", nil
    end

    -- Check if on handler
    if handler_name then
      local handler_pattern = "['\"]" .. handler_name .. "['\"]"
      local handler_start = tag_content:find(handler_pattern)
      if handler_start then
        -- Find parent component
        local parent = nil
        local search_content = content:sub(1, offset)
        for tag in search_content:gmatch("{%%%-?%s*component_block%s+['\"]([^'\"]+)['\"]") do
          parent = tag
        end
        if cursor_in_tag >= handler_start and cursor_in_tag <= handler_start + #handler_name + 2 then
          return handler_name, "handler", parent
        end
      end
    end

    -- Check for modifier
    local full_event = tag_content:match("{%%%-?%s*on%s+['\"]([^'\"]+)['\"]")
    if full_event and full_event:match("%.") then
      local modifier_name = full_event:match("%.([^%.]+)$")
      if modifier_name then
        return modifier_name, "modifier", nil
      end
    end
  end

  return nil, nil, nil
end

---Show hover at cursor position
function M.show_hover()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  -- Check if filetype is supported
  local ft = vim.bo.filetype
  if not parser.is_supported_filetype(ft) then
    -- Fall back to default K
    vim.lsp.buf.hover()
    return
  end

  -- Check if metadata is loaded
  if not metadata.is_loaded() then
    vim.notify("[wireview] Metadata not loaded. Run :WireviewRefresh first.", vim.log.levels.WARN)
    return
  end

  local content = utils.get_buffer_content(bufnr)
  local offset = utils.position_to_offset(bufnr, row, col)

  local target_name, target_type, component_name = extract_target(content, offset)

  local hover_lines = nil

  if target_type == "component" and target_name then
    local component = metadata.get_component(target_name)
    if component then
      hover_lines = build_component_hover(component)
    end
  elseif target_type == "handler" and target_name and component_name then
    local component = metadata.get_component(component_name)
    if component and component.methods and component.methods[target_name] then
      hover_lines = build_handler_hover(target_name, component.methods[target_name])
    end
  elseif target_type == "attribute" and target_name and component_name then
    local component = metadata.get_component(component_name)
    if component and component.fields and component.fields[target_name] then
      hover_lines = build_attribute_hover(target_name, component.fields[target_name])
    end
  elseif target_type == "modifier" and target_name then
    local modifier = metadata.get_modifier(target_name)
    if modifier then
      hover_lines = build_modifier_hover(target_name, modifier)
    end
  elseif target_type == "event" and target_name then
    hover_lines = { "**DOM Event:** `" .. target_name .. "`" }
  end

  if not hover_lines or #hover_lines == 0 then
    -- Try context-based hover
    local context = parser.get_cursor_context(bufnr, row, col)

    if context.component_name then
      local component = metadata.get_component(context.component_name)
      if component then
        hover_lines = build_component_hover(component)
      end
    end
  end

  if hover_lines and #hover_lines > 0 then
    vim.lsp.util.open_floating_preview(hover_lines, "markdown", {
      border = "rounded",
      focusable = true,
      focus = false,
      max_width = 80,
      max_height = 30,
    })
  else
    vim.notify("[wireview] No hover information available", vim.log.levels.INFO)
  end
end

---Get hover content without displaying (for LSP integration)
---@return string[]|nil
function M.get_hover_content()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  if not metadata.is_loaded() then
    return nil
  end

  local content = utils.get_buffer_content(bufnr)
  local offset = utils.position_to_offset(bufnr, row, col)

  local target_name, target_type, component_name = extract_target(content, offset)

  if target_type == "component" and target_name then
    local component = metadata.get_component(target_name)
    if component then
      return build_component_hover(component)
    end
  end

  return nil
end

return M

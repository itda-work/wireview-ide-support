---@mod wireview.definition Go-to-definition handler for wireview
---@brief [[
---Provides navigation to component and handler definitions in Python files.
---@brief ]]

local M = {}

local parser = require("wireview.parser")
local metadata = require("wireview.metadata")
local utils = require("wireview.utils")

---@class Location
---@field file string File path
---@field line number Line number (1-indexed)
---@field column number Column number (0-indexed)

---Get component definition location
---@param component_name string Component name
---@return Location|nil
local function get_component_location(component_name)
  local component = metadata.get_component(component_name)
  if not component then
    return nil
  end

  return {
    file = component.file_path,
    line = component.line_number,
    column = 0,
  }
end

---Get handler definition location
---@param component_name string Component name
---@param handler_name string Handler name
---@return Location|nil
local function get_handler_location(component_name, handler_name)
  local component = metadata.get_component(component_name)
  if not component or not component.methods then
    return nil
  end

  local method = component.methods[handler_name]
  if not method then
    return nil
  end

  return {
    file = component.file_path,
    line = method.line_number or component.line_number,
    column = 0,
  }
end

---Extract target from cursor context
---@param content string Buffer content
---@param offset number Cursor offset
---@return string|nil target_name Target name to find
---@return string|nil target_type Type of target ("component", "handler", "slot")
---@return string|nil component_name Parent component name
local function extract_target(content, offset)
  -- Find the enclosing tag
  local tag_start = nil
  local tag_end = nil
  local tag_content = nil

  -- Find {% ... %} containing cursor
  local search_pos = 1
  while true do
    local s, e = content:find("{%%.-%%}", search_pos)
    if not s then
      break
    end

    if s <= offset + 1 and e >= offset + 1 then
      tag_start = s
      tag_end = e
      tag_content = content:sub(s, e)
      break
    end

    search_pos = e + 1
  end

  if not tag_content then
    return nil, nil, nil
  end

  local cursor_in_tag = offset - tag_start + 2

  -- Check if it's a component tag
  local comp_name = tag_content:match("{%%%-?%s*component[_block]*%s+['\"]([^'\"]+)['\"]")
  if comp_name then
    -- Check if cursor is on component name
    local name_start = tag_content:find(comp_name, 1, true)
    if name_start and cursor_in_tag >= name_start and cursor_in_tag <= name_start + #comp_name then
      return comp_name, "component", nil
    end

    -- Check if cursor is on an attribute name
    local before_cursor = tag_content:sub(1, cursor_in_tag)
    local attr_name = before_cursor:match("(%w+)%s*=$") or before_cursor:match("(%w+)%s*=%s*['\"][^'\"]*$")
    if attr_name then
      return attr_name, "attribute", comp_name
    end
  end

  -- Check if it's an on tag
  local event_name, handler_name = tag_content:match("{%%%-?%s*on%s+['\"]([^'\"]+)['\"]%s+['\"]([^'\"]+)['\"]")
  if event_name and handler_name then
    -- Check if cursor is on handler name
    local handler_start = tag_content:find(handler_name, 1, true)
    if handler_start then
      -- Account for the first occurrence being the event
      local second_occurrence = tag_content:find(handler_name, handler_start + 1, true)
      if second_occurrence and cursor_in_tag >= second_occurrence and cursor_in_tag <= second_occurrence + #handler_name then
        -- Find parent component
        local parent_component = nil
        local search_content = content:sub(1, offset)
        for tag in search_content:gmatch("{%%%-?%s*component_block%s+['\"]([^'\"]+)['\"]") do
          parent_component = tag
        end
        return handler_name, "handler", parent_component
      end
    end
  end

  -- Check if it's a fill tag
  local slot_name = tag_content:match("{%%%-?%s*fill%s+['\"]?([%w_]+)['\"]?")
  if slot_name then
    return slot_name, "slot", nil
  end

  return nil, nil, nil
end

---Navigate to location
---@param location Location Location to navigate to
local function navigate_to(location)
  if not location or not location.file then
    vim.notify("[wireview] Definition not found", vim.log.levels.WARN)
    return
  end

  -- Check if file exists
  if vim.fn.filereadable(location.file) ~= 1 then
    vim.notify("[wireview] File not found: " .. location.file, vim.log.levels.ERROR)
    return
  end

  -- Open file
  vim.cmd("edit " .. vim.fn.fnameescape(location.file))

  -- Move cursor to line
  local line = location.line or 1
  local col = location.column or 0
  vim.api.nvim_win_set_cursor(0, { line, col })

  -- Center the screen
  vim.cmd("normal! zz")

  utils.log("Navigated to " .. location.file .. ":" .. line)
end

---Go to definition at cursor position
function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  -- Check if filetype is supported
  local ft = vim.bo.filetype
  if not parser.is_supported_filetype(ft) then
    -- Fall back to default gd
    vim.cmd("normal! gd")
    return
  end

  -- Check if metadata is loaded
  if not metadata.is_loaded() then
    vim.notify("[wireview] Metadata not loaded. Run :WireviewRefresh first.", vim.log.levels.WARN)
    return
  end

  local content = utils.get_buffer_content(bufnr)
  local offset = utils.position_to_offset(bufnr, row, col)

  -- Get cursor context
  local context = parser.get_cursor_context(bufnr, row, col)

  local location = nil

  if context.position == "component_name" or context.tag_type == "component" or context.tag_type == "component_block" then
    -- Try to find component name under cursor
    local target_name, target_type, parent_comp = extract_target(content, offset)

    if target_type == "component" and target_name then
      location = get_component_location(target_name)
    elseif target_type == "handler" and target_name and parent_comp then
      location = get_handler_location(parent_comp, target_name)
    elseif context.component_name then
      location = get_component_location(context.component_name)
    end
  elseif context.position == "handler_name" then
    local target_name, target_type, parent_comp = extract_target(content, offset)
    if target_type == "handler" and target_name and parent_comp then
      location = get_handler_location(parent_comp, target_name)
    elseif context.component_name then
      -- Try with current context
      local handler = content:match("['\"]([%w_]+)['\"]%s*%%}")
      if handler then
        location = get_handler_location(context.component_name, handler)
      end
    end
  elseif context.position == "attribute_name" or context.position == "attribute_value" then
    if context.component_name then
      location = get_component_location(context.component_name)
    end
  else
    -- Try generic extraction
    local target_name, target_type, parent_comp = extract_target(content, offset)

    if target_type == "component" and target_name then
      location = get_component_location(target_name)
    elseif target_type == "handler" and target_name and parent_comp then
      location = get_handler_location(parent_comp, target_name)
    end
  end

  if location then
    navigate_to(location)
  else
    vim.notify("[wireview] No definition found at cursor", vim.log.levels.INFO)
  end
end

---Get definition location without navigating (for LSP integration)
---@return Location|nil
function M.get_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1], pos[2]

  if not metadata.is_loaded() then
    return nil
  end

  local content = utils.get_buffer_content(bufnr)
  local offset = utils.position_to_offset(bufnr, row, col)

  local target_name, target_type, parent_comp = extract_target(content, offset)

  if target_type == "component" and target_name then
    return get_component_location(target_name)
  elseif target_type == "handler" and target_name and parent_comp then
    return get_handler_location(parent_comp, target_name)
  end

  return nil
end

return M

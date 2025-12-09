---@mod wireview.parser Template parser for wireview
---@brief [[
---Parses Django templates to detect cursor context within wireview tags.
---Uses Lua pattern matching for Django template tag parsing.
---@brief ]]

local M = {}

local utils = require("wireview.utils")

---@alias CursorPosition
---| "component_name"   # In component name: {% component 'Counter'| %}
---| "attribute_name"   # In attribute name: {% component 'Counter' cou| %}
---| "attribute_value"  # In attribute value: {% component 'Counter' count=| %}
---| "handler_name"     # In handler: {% on 'click' increment| %}
---| "event_name"       # In event: {% on 'click'| %}
---| "modifier"         # In modifier: {% on 'click.debounce'| %}
---| "slot_name"        # In slot: {% fill slotname| %}
---| "outside"          # Outside wireview tags

---@alias TagType
---| "component"        # {% component 'Name' %}
---| "component_block"  # {% component_block 'Name' %} ... {% endcomponent_block %}
---| "on"               # {% on 'event' 'handler' %}
---| "fill"             # {% fill slotname %}
---| "render_slot"      # {% render_slot slotname %}

---@class CursorContext
---@field in_wireview_tag boolean Whether cursor is inside a wireview tag
---@field tag_type TagType|nil Type of wireview tag
---@field position CursorPosition Cursor position within tag
---@field component_name string|nil Component name if available
---@field current_value string|nil Partial text at cursor (for filtering)
---@field attribute_name string|nil Attribute name if in attribute context
---@field event_name string|nil Event name if in event context

---Wireview tag types
local TAG_TYPES = {
  "component",
  "component_block",
  "on",
  "fill",
  "render_slot",
}

---Find the Django tag containing the cursor position
---@param content string Buffer content
---@param offset number Byte offset of cursor
---@return string|nil tag_content Content of the tag
---@return number|nil tag_start Start offset of tag
---@return number|nil tag_end End offset of tag
local function find_enclosing_tag(content, offset)
  -- Find all {% ... %} tags
  local last_match_start = nil
  local last_match_end = nil
  local last_match_content = nil

  -- Iterate through all tags
  local search_pos = 1
  while true do
    local tag_start, tag_end = content:find("{%%.-%%}", search_pos)
    if not tag_start then
      break
    end

    -- Check if cursor is within this tag
    if tag_start <= offset + 1 and tag_end >= offset + 1 then
      return content:sub(tag_start, tag_end), tag_start - 1, tag_end - 1
    end

    -- Track last tag before cursor for context
    if tag_end < offset + 1 then
      last_match_start = tag_start - 1
      last_match_end = tag_end - 1
      last_match_content = content:sub(tag_start, tag_end)
    end

    search_pos = tag_end + 1
  end

  return nil, nil, nil
end

---Detect the tag type from tag content
---@param tag_content string Content of the tag
---@return TagType|nil
local function detect_tag_type(tag_content)
  -- Extract first word after {%
  local first_word = tag_content:match("{%%%-?%s*(%w+)")
  if not first_word then
    return nil
  end

  for _, tag_type in ipairs(TAG_TYPES) do
    if first_word == tag_type then
      return tag_type
    end
  end

  return nil
end

---Parse component tag context
---@param tag_content string Tag content
---@param cursor_in_tag number Cursor position within tag
---@return CursorContext
local function parse_component_tag(tag_content, cursor_in_tag)
  local context = {
    in_wireview_tag = true,
    tag_type = detect_tag_type(tag_content),
    position = "outside",
    component_name = nil,
    current_value = nil,
    attribute_name = nil,
    event_name = nil,
  }

  -- Content before cursor (within tag)
  local before_cursor = tag_content:sub(1, cursor_in_tag)

  -- Extract component name pattern: {% component 'Name' or {% component "Name"
  local comp_name = tag_content:match("{%%%-?%s*component[_block]*%s+['\"]([^'\"]*)['\"]")
  context.component_name = comp_name

  -- Check if cursor is in component name position
  -- Pattern: {% component '...|
  local in_name_single = before_cursor:match("{%%%-?%s*component[_block]*%s+'([^']*)$")
  local in_name_double = before_cursor:match("{%%%-?%s*component[_block]*%s+\"([^\"]*)$")

  if in_name_single then
    context.position = "component_name"
    context.current_value = in_name_single
    return context
  end

  if in_name_double then
    context.position = "component_name"
    context.current_value = in_name_double
    return context
  end

  -- Check if we're after component name (in attributes section)
  local after_name = before_cursor:match("['\"]%s+(.*)$")
  if after_name then
    -- Check if we're in attribute value: name=|
    local attr_name = after_name:match("(%w+)%s*=%s*$")
    if attr_name then
      context.position = "attribute_value"
      context.attribute_name = attr_name
      context.current_value = ""
      return context
    end

    -- Check if we're in attribute value with quote: name='|
    local attr_with_quote, partial_value = after_name:match("(%w+)%s*=%s*['\"]([^'\"]*)$")
    if attr_with_quote then
      context.position = "attribute_value"
      context.attribute_name = attr_with_quote
      context.current_value = partial_value
      return context
    end

    -- Check if we're typing attribute name: name| or partial|
    local partial_attr = after_name:match("(%w*)$")
    if partial_attr then
      context.position = "attribute_name"
      context.current_value = partial_attr
      return context
    end
  end

  -- Default to attribute name position if we're after component name
  if comp_name and before_cursor:match("['\"]%s*") then
    context.position = "attribute_name"
    context.current_value = ""
  end

  return context
end

---Parse on tag context
---@param tag_content string Tag content
---@param cursor_in_tag number Cursor position within tag
---@return CursorContext
local function parse_on_tag(tag_content, cursor_in_tag)
  local context = {
    in_wireview_tag = true,
    tag_type = "on",
    position = "outside",
    component_name = nil,
    current_value = nil,
    attribute_name = nil,
    event_name = nil,
  }

  local before_cursor = tag_content:sub(1, cursor_in_tag)

  -- Extract event name: {% on 'click' or {% on "click"
  local event_name = tag_content:match("{%%%-?%s*on%s+['\"]([^'\"%.]*)")
  context.event_name = event_name

  -- Check if cursor is in event name position
  -- Pattern: {% on '...|
  local in_event_single = before_cursor:match("{%%%-?%s*on%s+'([^']*)$")
  local in_event_double = before_cursor:match("{%%%-?%s*on%s+\"([^\"]*)$")

  if in_event_single then
    -- Check for modifier: {% on 'click.|
    if in_event_single:match("%.") then
      context.position = "modifier"
      context.current_value = in_event_single:match("%.([^%.]*)$") or ""
      context.event_name = in_event_single:match("^([^%.]+)")
    else
      context.position = "event_name"
      context.current_value = in_event_single
    end
    return context
  end

  if in_event_double then
    if in_event_double:match("%.") then
      context.position = "modifier"
      context.current_value = in_event_double:match("%.([^%.]*)$") or ""
      context.event_name = in_event_double:match("^([^%.]+)")
    else
      context.position = "event_name"
      context.current_value = in_event_double
    end
    return context
  end

  -- Check if we're in handler name position
  -- Pattern: {% on 'event' '...|
  local in_handler_single = before_cursor:match("['\"]%s+['\"]([^']*)$")
  local in_handler_double = before_cursor:match("['\"]%s+\"([^\"]*)$")

  if in_handler_single then
    context.position = "handler_name"
    context.current_value = in_handler_single
    return context
  end

  if in_handler_double then
    context.position = "handler_name"
    context.current_value = in_handler_double
    return context
  end

  -- Check if we're after event name, expecting handler
  if before_cursor:match("['\"]%s+$") then
    context.position = "handler_name"
    context.current_value = ""
    return context
  end

  return context
end

---Parse fill tag context
---@param tag_content string Tag content
---@param cursor_in_tag number Cursor position within tag
---@return CursorContext
local function parse_fill_tag(tag_content, cursor_in_tag)
  local context = {
    in_wireview_tag = true,
    tag_type = "fill",
    position = "outside",
    component_name = nil,
    current_value = nil,
    attribute_name = nil,
    event_name = nil,
  }

  local before_cursor = tag_content:sub(1, cursor_in_tag)

  -- Check if cursor is in slot name position
  -- Pattern: {% fill slotname| or {% fill 'slotname|
  local in_slot_bare = before_cursor:match("{%%%-?%s*fill%s+(%w*)$")
  local in_slot_single = before_cursor:match("{%%%-?%s*fill%s+'([^']*)$")
  local in_slot_double = before_cursor:match("{%%%-?%s*fill%s+\"([^\"]*)$")

  if in_slot_bare then
    context.position = "slot_name"
    context.current_value = in_slot_bare
    return context
  end

  if in_slot_single then
    context.position = "slot_name"
    context.current_value = in_slot_single
    return context
  end

  if in_slot_double then
    context.position = "slot_name"
    context.current_value = in_slot_double
    return context
  end

  return context
end

---Parse render_slot tag context
---@param tag_content string Tag content
---@param cursor_in_tag number Cursor position within tag
---@return CursorContext
local function parse_render_slot_tag(tag_content, cursor_in_tag)
  local context = {
    in_wireview_tag = true,
    tag_type = "render_slot",
    position = "outside",
    component_name = nil,
    current_value = nil,
    attribute_name = nil,
    event_name = nil,
  }

  local before_cursor = tag_content:sub(1, cursor_in_tag)

  -- Check if cursor is in slot name position
  local in_slot_bare = before_cursor:match("{%%%-?%s*render_slot%s+(%w*)$")
  local in_slot_single = before_cursor:match("{%%%-?%s*render_slot%s+'([^']*)$")
  local in_slot_double = before_cursor:match("{%%%-?%s*render_slot%s+\"([^\"]*)$")

  if in_slot_bare then
    context.position = "slot_name"
    context.current_value = in_slot_bare
    return context
  end

  if in_slot_single then
    context.position = "slot_name"
    context.current_value = in_slot_single
    return context
  end

  if in_slot_double then
    context.position = "slot_name"
    context.current_value = in_slot_double
    return context
  end

  return context
end

---Find parent component for nested tags (like on, fill)
---@param content string Full buffer content
---@param offset number Current cursor offset
---@return string|nil Component name of parent component_block
local function find_parent_component(content, offset)
  -- Find all component_block tags before cursor
  local search_content = content:sub(1, offset)
  local component_stack = {}

  -- Track opening and closing component_block tags
  for tag in search_content:gmatch("{%%%-?%s*(%w+[^%%]-)%%}") do
    local tag_type, name = tag:match("^(component_block)%s+['\"]([^'\"]+)['\"]")
    if tag_type then
      table.insert(component_stack, name)
    elseif tag:match("^endcomponent_block") then
      if #component_stack > 0 then
        table.remove(component_stack)
      end
    end
  end

  if #component_stack > 0 then
    return component_stack[#component_stack]
  end

  return nil
end

---Get cursor context from buffer
---@param bufnr number Buffer number
---@param row number 1-indexed row
---@param col number 0-indexed column
---@return CursorContext
function M.get_cursor_context(bufnr, row, col)
  local content = utils.get_buffer_content(bufnr)
  local offset = utils.position_to_offset(bufnr, row, col)

  return M.get_cursor_context_from_string(content, offset)
end

---Get cursor context from string (for testing)
---@param content string Buffer content
---@param offset number Byte offset
---@return CursorContext
function M.get_cursor_context_from_string(content, offset)
  local default_context = {
    in_wireview_tag = false,
    tag_type = nil,
    position = "outside",
    component_name = nil,
    current_value = nil,
    attribute_name = nil,
    event_name = nil,
  }

  -- Find enclosing tag
  local tag_content, tag_start, tag_end = find_enclosing_tag(content, offset)

  if not tag_content then
    return default_context
  end

  -- Cursor position within tag
  local cursor_in_tag = offset - tag_start + 1

  -- Detect tag type
  local tag_type = detect_tag_type(tag_content)

  if not tag_type then
    return default_context
  end

  -- Parse based on tag type
  local context
  if tag_type == "component" or tag_type == "component_block" then
    context = parse_component_tag(tag_content, cursor_in_tag)
  elseif tag_type == "on" then
    context = parse_on_tag(tag_content, cursor_in_tag)
    -- Find parent component for on tags
    if not context.component_name then
      context.component_name = find_parent_component(content, offset)
    end
  elseif tag_type == "fill" then
    context = parse_fill_tag(tag_content, cursor_in_tag)
    context.component_name = find_parent_component(content, offset)
  elseif tag_type == "render_slot" then
    context = parse_render_slot_tag(tag_content, cursor_in_tag)
  else
    return default_context
  end

  return context
end

---Check if filetype is supported
---@param filetype string
---@return boolean
function M.is_supported_filetype(filetype)
  return filetype == "htmldjango" or filetype == "html"
end

return M

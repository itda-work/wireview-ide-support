---@mod wireview.telescope Telescope integration for wireview
---@brief [[
---Provides Telescope pickers for searching wireview components.
---@brief ]]

local M = {}

local metadata = require("wireview.metadata")

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

---Build preview content for component
---@param component ComponentMetadata
---@return string[]
local function build_preview_content(component)
  local lines = {}

  table.insert(lines, "# " .. component.name)
  table.insert(lines, "")
  table.insert(lines, "**FQN:** `" .. component.fqn .. "`")
  table.insert(lines, "**App Key:** `" .. component.app_key .. "`")
  table.insert(lines, "**File:** `" .. component.file_path .. ":" .. component.line_number .. "`")

  if component.template_name and component.template_name ~= "" then
    table.insert(lines, "**Template:** `" .. component.template_name .. "`")
  end

  if component.docstring and component.docstring ~= "" then
    table.insert(lines, "")
    table.insert(lines, "## Description")
    table.insert(lines, "")
    table.insert(lines, component.docstring)
  end

  -- Fields
  if component.fields and next(component.fields) then
    table.insert(lines, "")
    table.insert(lines, "## Fields")
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
  end

  -- Event handlers
  local async_methods = {}
  if component.methods then
    for name, method in pairs(component.methods) do
      if method.is_async and not is_excluded_method(name) then
        async_methods[name] = method
      end
    end
  end

  if next(async_methods) then
    table.insert(lines, "")
    table.insert(lines, "## Event Handlers")
    table.insert(lines, "")
    for name, method in pairs(async_methods) do
      local params = {}
      if method.parameters then
        for param_name, param_info in pairs(method.parameters) do
          local param_str = param_name
          if param_info.type then
            param_str = param_str .. ": " .. param_info.type
          end
          table.insert(params, param_str)
        end
      end
      table.insert(lines, "- `" .. name .. "(" .. table.concat(params, ", ") .. ")`")
    end
  end

  -- Slots
  if component.slots and next(component.slots) then
    table.insert(lines, "")
    table.insert(lines, "## Slots")
    table.insert(lines, "")
    for name, slot in pairs(component.slots) do
      local slot_line = "- `" .. name .. "`"
      if slot.required then
        slot_line = slot_line .. " *(required)*"
      end
      table.insert(lines, slot_line)
    end
  end

  return lines
end

---Components picker
---@param opts? table Telescope options
function M.components(opts)
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("[wireview] telescope.nvim is required for this feature", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")

  opts = opts or {}

  -- Ensure metadata is loaded
  if not metadata.is_loaded() then
    metadata.refresh(function(success)
      if success then
        M.components(opts)
      else
        vim.notify("[wireview] Failed to load metadata", vim.log.levels.ERROR)
      end
    end)
    return
  end

  -- Get all components
  local components = metadata.get_all_components()
  local component_list = {}
  for _, component in pairs(components) do
    table.insert(component_list, component)
  end

  -- Sort by name
  table.sort(component_list, function(a, b)
    return a.name < b.name
  end)

  pickers.new(opts, {
    prompt_title = "Wireview Components",
    finder = finders.new_table({
      results = component_list,
      entry_maker = function(component)
        -- Count fields and methods
        local field_count = component.fields and vim.tbl_count(component.fields) or 0
        local method_count = 0
        if component.methods then
          for name, method in pairs(component.methods) do
            if method.is_async and not is_excluded_method(name) then
              method_count = method_count + 1
            end
          end
        end

        local display = string.format(
          "%-30s  %s  [%d fields, %d handlers]",
          component.name,
          component.fqn,
          field_count,
          method_count
        )

        return {
          value = component,
          display = display,
          ordinal = component.name .. " " .. component.fqn .. " " .. component.app_key,
          filename = component.file_path,
          lnum = component.line_number,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = previewers.new_buffer_previewer({
      title = "Component Info",
      define_preview = function(self, entry)
        local component = entry.value
        local preview_lines = build_preview_content(component)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)
        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      end,
    }),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
          vim.cmd("normal! zz")
        end
      end)
      return true
    end,
  }):find()
end

---Register Telescope extension
---@return table
function M.register_extension()
  return require("telescope").register_extension({
    exports = {
      wireview = M.components,
      components = M.components,
    },
  })
end

---Setup command
function M.setup()
  vim.api.nvim_create_user_command("Telescope wireview", function(cmd_opts)
    local subcommand = cmd_opts.fargs[1] or "components"
    if subcommand == "components" or subcommand == "" then
      M.components()
    else
      vim.notify("[wireview] Unknown subcommand: " .. subcommand, vim.log.levels.WARN)
    end
  end, {
    nargs = "?",
    complete = function()
      return { "components" }
    end,
    desc = "Wireview Telescope picker",
  })
end

return M

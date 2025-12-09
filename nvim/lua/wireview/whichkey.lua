---@mod wireview.whichkey Which-key integration for wireview
---@brief [[
---Provides which-key keybinding group for wireview commands.
---@brief ]]

local M = {}

---Default keybinding prefix
M.prefix = "<leader>w"

---Setup which-key integration
---@param opts? table Options (prefix: string)
function M.setup(opts)
  opts = opts or {}
  local prefix = opts.prefix or M.prefix

  local ok, wk = pcall(require, "which-key")
  if not ok then
    -- which-key not available, skip
    return
  end

  -- Check which-key version (v3 uses different API)
  local has_add = type(wk.add) == "function"

  if has_add then
    -- which-key v3 API
    wk.add({
      { prefix, group = "Wireview" },
      { prefix .. "r", "<cmd>WireviewRefresh<cr>", desc = "Refresh metadata" },
      { prefix .. "s", "<cmd>WireviewStatus<cr>", desc = "Show status" },
      { prefix .. "d", function() require("wireview.definition").goto_definition() end, desc = "Go to definition" },
      { prefix .. "h", function() require("wireview.hover").show_hover() end, desc = "Show hover" },
      { prefix .. "f", function() require("wireview.telescope").components() end, desc = "Find components" },
    })
  else
    -- which-key v2 API (legacy)
    wk.register({
      [prefix] = {
        name = "Wireview",
        r = { "<cmd>WireviewRefresh<cr>", "Refresh metadata" },
        s = { "<cmd>WireviewStatus<cr>", "Show status" },
        d = { function() require("wireview.definition").goto_definition() end, "Go to definition" },
        h = { function() require("wireview.hover").show_hover() end, "Show hover" },
        f = { function() require("wireview.telescope").components() end, "Find components" },
      },
    })
  end
end

return M

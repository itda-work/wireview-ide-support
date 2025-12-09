---@mod wireview.utils Utility functions for wireview
---@brief [[
---Shared utility functions for file operations, workspace detection,
---and debug logging.
---@brief ]]

local M = {}

---Candidates for manage.py location
local MANAGE_PY_CANDIDATES = {
  "manage.py",
  "src/manage.py",
  "backend/manage.py",
  "server/manage.py",
  "app/manage.py",
  "tests/manage.py",
  "example/manage.py",
  "examples/manage.py",
}

---Directories to skip when searching
local SKIP_DIRS = {
  "node_modules",
  "__pycache__",
  ".git",
  ".venv",
  "venv",
  ".env",
  "env",
  ".tox",
  ".mypy_cache",
  ".pytest_cache",
  "dist",
  "build",
  "egg-info",
}

---Log a debug message
---@param msg string Message to log
---@param level? number Log level (default: DEBUG)
function M.log(msg, level)
  local config = require("wireview.config")
  if not config.is_setup() or not config.get("debug") then
    return
  end
  vim.notify("[wireview] " .. msg, level or vim.log.levels.DEBUG)
end

---Get the workspace root directory
---@return string|nil Root directory path
function M.get_workspace_root()
  -- Try to get from LSP first
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end

  -- Try to find git root
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and vim.fn.isdirectory(git_root) == 1 then
    return git_root
  end

  -- Fallback to current working directory
  return vim.fn.getcwd()
end

---Check if a path should be skipped
---@param path string Path to check
---@return boolean
local function should_skip(path)
  local name = vim.fn.fnamemodify(path, ":t")
  for _, skip in ipairs(SKIP_DIRS) do
    if name == skip or vim.startswith(name, ".") then
      return true
    end
  end
  return false
end

---Find manage.py in the workspace
---@param root? string Root directory to search from
---@return string|nil Path to manage.py
function M.find_manage_py(root)
  root = root or M.get_workspace_root()
  if not root then
    return nil
  end

  -- Check common candidate paths first
  for _, candidate in ipairs(MANAGE_PY_CANDIDATES) do
    local path = root .. "/" .. candidate
    if vim.fn.filereadable(path) == 1 then
      M.log("Found manage.py at: " .. path)
      return path
    end
  end

  -- Recursive search with depth limit
  local function search(dir, depth)
    if depth > 3 then
      return nil
    end

    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return nil
    end

    local subdirs = {}
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir .. "/" .. name

      if name == "manage.py" and type == "file" then
        M.log("Found manage.py at: " .. full_path)
        return full_path
      end

      if type == "directory" and not should_skip(full_path) then
        table.insert(subdirs, full_path)
      end
    end

    -- Search subdirectories
    for _, subdir in ipairs(subdirs) do
      local result = search(subdir, depth + 1)
      if result then
        return result
      end
    end

    return nil
  end

  local result = search(root, 0)
  if not result then
    M.log("manage.py not found in workspace", vim.log.levels.WARN)
  end
  return result
end

---Check if current workspace is a Django project
---@return boolean
function M.is_django_project()
  local root = M.get_workspace_root()
  if not root then
    return false
  end

  -- Check for manage.py
  if M.find_manage_py(root) then
    return true
  end

  -- Check for Django in requirements
  local req_files = { "requirements.txt", "pyproject.toml", "setup.py", "Pipfile" }
  for _, req_file in ipairs(req_files) do
    local path = root .. "/" .. req_file
    if vim.fn.filereadable(path) == 1 then
      local content = vim.fn.readfile(path)
      for _, line in ipairs(content) do
        if line:match("[Dd]jango") then
          return true
        end
      end
    end
  end

  return false
end

---Get absolute path for metadata file
---@return string
function M.get_metadata_path()
  local config = require("wireview.config")
  local metadata_path = config.get("metadata_path")
  local root = M.get_workspace_root() or vim.fn.getcwd()

  -- If already absolute, return as-is
  if vim.fn.fnamemodify(metadata_path, ":p") == metadata_path then
    return metadata_path
  end

  return root .. "/" .. metadata_path
end

---Ensure directory exists
---@param path string Directory path
---@return boolean Success
function M.ensure_dir(path)
  if vim.fn.isdirectory(path) == 1 then
    return true
  end
  return vim.fn.mkdir(path, "p") == 1
end

---Read JSON file
---@param path string File path
---@return table|nil Parsed JSON, nil on error
function M.read_json(path)
  if vim.fn.filereadable(path) ~= 1 then
    M.log("File not readable: " .. path, vim.log.levels.DEBUG)
    return nil
  end

  local content = vim.fn.readfile(path)
  if not content or #content == 0 then
    M.log("Empty file: " .. path, vim.log.levels.DEBUG)
    return nil
  end

  local ok, result = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok then
    M.log("JSON parse error: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end

  return result
end

---Write JSON file
---@param path string File path
---@param data table Data to write
---@return boolean Success
function M.write_json(path, data)
  local dir = vim.fn.fnamemodify(path, ":h")
  if not M.ensure_dir(dir) then
    M.log("Failed to create directory: " .. dir, vim.log.levels.ERROR)
    return false
  end

  local ok, json = pcall(vim.fn.json_encode, data)
  if not ok then
    M.log("JSON encode error: " .. tostring(json), vim.log.levels.ERROR)
    return false
  end

  local result = vim.fn.writefile({ json }, path)
  return result == 0
end

---Parse ISO 8601 timestamp
---@param timestamp string ISO 8601 timestamp
---@return number|nil Unix timestamp
function M.parse_timestamp(timestamp)
  if not timestamp then
    return nil
  end

  -- Pattern: 2024-01-15T10:00:00Z or 2024-01-15T10:00:00+00:00
  local year, month, day, hour, min, sec = timestamp:match(
    "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
  )

  if not year then
    return nil
  end

  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
  })
end

---Check if timestamp is within TTL
---@param timestamp string ISO 8601 timestamp
---@param ttl number TTL in seconds
---@return boolean
function M.is_cache_valid(timestamp, ttl)
  local cache_time = M.parse_timestamp(timestamp)
  if not cache_time then
    return false
  end

  local now = os.time()
  return (now - cache_time) < ttl
end

---Escape string for use in Lua pattern
---@param str string String to escape
---@return string Escaped string
function M.escape_pattern(str)
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

---Get buffer content as string
---@param bufnr number Buffer number
---@return string
function M.get_buffer_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

---Convert (row, col) to byte offset
---@param bufnr number Buffer number
---@param row number 1-indexed row
---@param col number 0-indexed column
---@return number Byte offset
function M.position_to_offset(bufnr, row, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row, false)
  local offset = 0
  for i = 1, #lines - 1 do
    offset = offset + #lines[i] + 1 -- +1 for newline
  end
  return offset + col
end

---Convert byte offset to (row, col)
---@param bufnr number Buffer number
---@param offset number Byte offset
---@return number row 1-indexed row
---@return number col 0-indexed column
function M.offset_to_position(bufnr, offset)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_offset = 0

  for i, line in ipairs(lines) do
    local line_length = #line + 1 -- +1 for newline
    if current_offset + line_length > offset then
      return i, offset - current_offset
    end
    current_offset = current_offset + line_length
  end

  -- Return last position if offset exceeds content
  return #lines, #lines[#lines]
end

return M

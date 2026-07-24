---@module 'recommender.project'
---@brief Project-wide (cwd) file discovery for multi-file chain analysis.
---@description
--- Only the regex-based analyzers (regex, javascript, python) support cwd
--- scope — they operate on plain text lines, so files read from disk work
--- the same way a buffer's lines do. The treesitter analyzer stays
--- buffer-only: it parses a live Neovim buffer's syntax tree, not raw file
--- text, so it is out of scope here (see `supports_cwd()`).
---
--- Files are read synchronously via `vim.fn.readfile()` — this plugin has no
--- async machinery, and a synchronous scan matches the rest of the codebase.
--- `cwd_max_files` (see `config/DEFAULTS.lua`) bounds the scan on large
--- repositories; `cwd_ignore` skips directories by exact path-segment name at
--- any depth (e.g. "node_modules", ".git").

local M = {}

---File extensions scanned per analyzer.
---@type table<string, string[]>
local EXTENSIONS = {
  regex = { "lua" },
  javascript = { "js", "jsx", "ts", "tsx" },
  python = { "py" },
}

---Whether `analyzer_name` supports project-wide (cwd) scope.
---@param analyzer_name string
---@return boolean
function M.supports_cwd(analyzer_name)
  return EXTENSIONS[analyzer_name] ~= nil
end

---Whether any path segment of `path` exactly matches an ignored name.
---@param path string
---@param ignore string[]
---@return boolean
local function is_ignored(path, ignore)
  if not ignore or #ignore == 0 then
    return false
  end
  for _, seg in ipairs(vim.split(path, "[/\\]")) do
    for _, name in ipairs(ignore) do
      if seg == name then
        return true
      end
    end
  end
  return false
end

---Find files under `cwd` matching the given analyzer's extensions.
---@param analyzer_name string
---@param cwd string
---@param ignore string[]
---@param max_files integer  0 (or nil) means unbounded
---@return string[] paths, boolean truncated
function M.find_files(analyzer_name, cwd, ignore, max_files)
  local exts = EXTENSIONS[analyzer_name]
  if not exts then
    return {}, false
  end

  local seen = {}
  local paths = {}
  for _, ext in ipairs(exts) do
    local ok, matches = pcall(vim.fn.globpath, cwd, "**/*." .. ext, false, true)
    if ok and type(matches) == "table" then
      for _, p in ipairs(matches) do
        if not seen[p] and not is_ignored(p, ignore) then
          seen[p] = true
          paths[#paths + 1] = p
        end
      end
    end
  end

  table.sort(paths)

  local truncated = false
  if max_files and max_files > 0 and #paths > max_files then
    truncated = true
    local capped = {}
    for i = 1, max_files do
      capped[i] = paths[i]
    end
    paths = capped
  end

  return paths, truncated
end

---Read every file's lines and concatenate them into one combined line list.
---Unreadable files (permission errors, race-deleted files, …) are skipped
---rather than aborting the whole scan.
---@param paths string[]
---@return string[]
function M.read_lines(paths)
  local lines = {}
  for _, p in ipairs(paths) do
    local ok, file_lines = pcall(vim.fn.readfile, p)
    if ok and type(file_lines) == "table" then
      for _, l in ipairs(file_lines) do
        lines[#lines + 1] = l
      end
    end
  end
  return lines
end

return M

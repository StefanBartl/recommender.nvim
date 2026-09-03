---@module 'recommender.project'
---@brief Multi-file/single-file chain discovery for every non-buffer scope.
---@description
--- Shared by `cwd` and `path` scope (`find_files` + reading over a directory
--- root — `getcwd()` for `cwd`, the current file's directory for `path`) and
--- by `cfile` scope (`read_lines` over a single resolved path). Only the
--- regex-based analyzers (regex, javascript, python, perf) support reading
--- from disk instead of a live buffer — they operate on plain text lines, so
--- file content works the same way a buffer's lines do. The treesitter
--- analyzer stays buffer-only: it parses a live Neovim buffer's syntax tree,
--- not raw file text, so it is out of scope here (see `supports_cwd()`,
--- which gates every non-buffer scope despite the name).
---
--- `find_files` lists matching paths with one `vim.fn.globpath()` call per
--- extension (native, not a Lua loop — fast even on a large tree, but fully
--- synchronous, and it walks into an ignored directory's whole subtree before
--- `cwd_ignore` ever gets a chance to drop it). `cwd_max_files` (see
--- `config/DEFAULTS.lua`) bounds the final list; `cwd_ignore` skips
--- directories by exact path-segment name at any depth (e.g. "node_modules",
--- ".git").
---
--- `find_files_async` does the same job through `vim.uv.fs_scandir` instead:
--- genuinely async (each directory read is a real libuv callback, not a
--- blocking call), and an ignored directory is never even opened, rather than
--- opened-then-discarded. Measured against this codebase's own tree, walking
--- into `node_modules` before filtering it out is exactly the shape of
--- "quietly wasted work" this rewrite exists to remove — see
--- `bindings/usrcmds.lua`, the only caller.
---
--- `read_lines` (sync, still used for the single-file `cfile` scope, and by
--- callers/tests that want the whole scan in one call) and `read_lines_async`
--- (used by `cwd`/`path` scope) share the same per-file `vim.fn.readfile()`
--- call and the same "skip unreadable files" behavior — the async version
--- just spreads that same work over batches scheduled on the event loop
--- instead of one tight `for` loop.
---
--- Together, `find_files_async` + `read_lines_async` are what make a
--- `cwd`/`path` scan across hundreds of files (each a real syscall, plus
--- whatever an AV/EDR hook adds per open/stat on Windows) never block Neovim
--- for the scan's full duration — only for one directory or one small batch
--- at a time, with a `lib.nvim.progress` indicator (`config.progress_style`)
--- tracking both phases.

local M = {}

local globbable = require("lib.nvim.fs.globbable")

---File extensions scanned per analyzer.
---@type table<string, string[]>
local EXTENSIONS = {
  regex = { "lua" },
  javascript = { "js", "jsx", "ts", "tsx" },
  python = { "py" },
  perf = { "lua" },
}

---Whether `analyzer_name` supports any non-buffer scope (`cwd`, `path`,
---`cfile`, `line`) — every one of them ends up calling `analyze()` with an
---explicit `lines` array, which only the regex-based analyzers accept.
---@param analyzer_name string
---@return boolean
function M.supports_cwd(analyzer_name)
  return EXTENSIONS[analyzer_name] ~= nil
end

---@internal
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
  -- Glob reads its argument as a pattern, so an 8.3 short root ("~1") is read
  -- as a home-directory reference and matches nothing at all -- silently, with
  -- the pcall below none the wiser. See lib.nvim.fs.globbable.
  cwd = globbable(cwd)
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

---Asynchronous equivalent of `find_files`: walks `root` via
---`vim.uv.fs_scandir` (a real libuv callback per directory, not a blocking
---call) instead of one synchronous `vim.fn.globpath()` per extension.
---
---Every directory-listing result is handled from inside `vim.schedule` --
---even though `fs_scandir_next`'s own drain loop is plain, API-free Lua and
---would be safe to run straight from the raw callback, `opts.on_progress`
---(via `lib.nvim.progress`) and eventually `opts.on_done` are not: they are
---expected to be safe to call `vim.fn`/`vim.api` from, which a libuv fast-event
---callback is not. One extra scheduled hop per directory buys that safety at
---a cost too small to matter next to the actual disk I/O.
---
---`ignore` is checked per directory *name* during the walk, so an ignored
---directory's contents are never scandir'd at all -- unlike `find_files`,
---which globs everything first and filters path segments afterward. A
---directory whose name starts with "." is *always* skipped too, on top of
---`ignore` -- matching `vim.fn.globpath()`'s own `**` wildcard, which does
---not descend into dotdirectories either. Confirmed the hard way: without
---this, a repository containing its own git worktrees under `.claude/`
---(this ecosystem's own convention) had every worktree's full source tree
---counted again as if it were part of the project, nearly tripling the file
---count `find_files` (sync) reports for the same root.
---`max_files` (if positive) additionally stops the walk from recursing into
---*new* directories once the cap is reached (already-in-flight ones still
---finish); `find_files` only caps the final list.
---
---`opts.is_cancelled`, checked before a directory's results are processed and
---again before `on_done`, makes a superseded scan (see the module-level
---`_scan_generation` in `bindings/usrcmds.lua`) stop recursing and never call
---`on_done` -- same contract as `read_lines_async`.
---@param analyzer_name string
---@param root string
---@param ignore string[]
---@param max_files integer  0 (or nil) means unbounded
---@param opts { on_progress?: fun(dirs_scanned:integer, files_found:integer), is_cancelled?: fun():boolean, on_done: fun(paths:string[], truncated:boolean) }
---@return nil
function M.find_files_async(analyzer_name, root, ignore, max_files, opts)
  local exts = EXTENSIONS[analyzer_name]
  if not exts then
    opts.on_done({}, false)
    return
  end

  local ext_set = {}
  for _, e in ipairs(exts) do
    ext_set[e] = true
  end

  local ignore_set = {}
  for _, name in ipairs(ignore or {}) do
    ignore_set[name] = true
  end

  local uv = vim.uv or vim.loop
  local paths = {}
  local dirs_scanned = 0
  -- Directories whose `fs_scandir` request is still outstanding, plus one
  -- for the root itself until its own callback runs. `on_done` fires exactly
  -- once, when this reaches 0 -- the walk's natural "nothing left in flight"
  -- signal, no separate depth-first/breadth-first bookkeeping needed.
  local pending = 0
  local finished = false
  -- Set the moment the walk skips recursing into a subdirectory because
  -- `max_files` was already reached (see `scan_dir` below) -- distinct from
  -- `#paths > max_files` below, because stopping early can leave `#paths`
  -- landing exactly *at* max_files with nothing left over to trim, which
  -- would otherwise (wrongly) look like a complete, untruncated scan.
  local hit_cap = false

  local function maybe_finish()
    if finished or pending > 0 then
      return
    end
    finished = true
    if opts.is_cancelled and opts.is_cancelled() then
      return -- cancelled; on_done is never called, same contract as read_lines_async
    end

    table.sort(paths)
    local truncated = hit_cap
    if max_files and max_files > 0 and #paths > max_files then
      truncated = true
      local capped = {}
      for i = 1, max_files do
        capped[i] = paths[i]
      end
      paths = capped
    end
    opts.on_done(paths, truncated)
  end

  local function scan_dir(dir)
    uv.fs_scandir(dir, function(_, handle)
      vim.schedule(function()
        pending = pending - 1
        if handle and not (opts.is_cancelled and opts.is_cancelled()) then
          dirs_scanned = dirs_scanned + 1
          local subdirs = {}
          while true do
            local name, typ = uv.fs_scandir_next(handle)
            if not name then
              break
            end
            if typ == "directory" then
              if not ignore_set[name] and name:sub(1, 1) ~= "." then
                subdirs[#subdirs + 1] = dir .. "/" .. name
              end
            elseif typ == "file" then
              local ext = name:match("%.([%w_]+)$")
              if ext and ext_set[ext] then
                paths[#paths + 1] = dir .. "/" .. name
              end
            end
          end

          if opts.on_progress then
            opts.on_progress(dirs_scanned, #paths)
          end

          local at_cap = max_files and max_files > 0 and #paths >= max_files
          if not at_cap then
            for _, sub in ipairs(subdirs) do
              pending = pending + 1
              scan_dir(sub)
            end
          elseif #subdirs > 0 then
            -- At least one subdirectory is being left unexplored because of
            -- the cap -- it may or may not contain further matches, but
            -- either way this is no longer a complete scan.
            hit_cap = true
          end
        end
        maybe_finish()
      end)
    end)
  end

  pending = 1
  -- `fs_scandir` (unlike `globpath`) takes a plain directory path, not a
  -- glob pattern -- the 8.3-short-path pitfall `find_files` guards against
  -- with `globbable()` does not apply here.
  scan_dir((root:gsub("[/\\]+$", "")))
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

---Default number of files read per batch before yielding back to the event
---loop — small enough that one batch never itself becomes the next visible
---freeze, large enough that a small scan still finishes in one or two ticks.
---@type integer
local DEFAULT_BATCH_SIZE = 20

---Read every file's lines, same as `read_lines`, but asynchronously: files
---are read in batches of `opts.batch_size`, with `vim.schedule` between
---batches so Neovim's event loop gets a turn — redraws, keypresses, and any
---`lib.nvim.progress` indicator's own scheduled updates — between each one,
---instead of blocking for the whole scan the way a single `for` loop would.
---
---`opts.is_cancelled`, if given, is checked before every batch; once it
---returns true the function stops silently and `opts.on_done` is never
---called — the caller (see `bindings/usrcmds.lua`) uses this to abandon a
---scan that a newer `:Recommender` invocation, or the user via the "float"/
---"kit" progress style's cancel keymap, has superseded.
---@param paths string[]
---@param opts { batch_size?: integer, on_progress?: fun(done:integer, total:integer), on_done: fun(lines:string[]), is_cancelled?: fun():boolean }
---@return nil
function M.read_lines_async(paths, opts)
  local batch_size = (opts.batch_size and opts.batch_size > 0) and opts.batch_size or DEFAULT_BATCH_SIZE
  local total = #paths
  local lines = {}
  local done_count = 0

  if total == 0 then
    if opts.on_progress then
      opts.on_progress(0, 0)
    end
    opts.on_done(lines)
    return
  end

  local function step()
    if opts.is_cancelled and opts.is_cancelled() then
      return
    end

    local batch_end = math.min(done_count + batch_size, total)
    for i = done_count + 1, batch_end do
      local ok, file_lines = pcall(vim.fn.readfile, paths[i])
      if ok and type(file_lines) == "table" then
        for _, l in ipairs(file_lines) do
          lines[#lines + 1] = l
        end
      end
    end
    done_count = batch_end

    if opts.on_progress then
      opts.on_progress(done_count, total)
    end

    if done_count < total then
      vim.schedule(step)
    else
      opts.on_done(lines)
    end
  end

  vim.schedule(step)
end

return M

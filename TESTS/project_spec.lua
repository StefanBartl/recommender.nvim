-- TESTS/project_spec.lua — recommender.project: which analyzers can be pointed
-- at something other than the current buffer, and how files are collected.

return function(H)
  local project = require("recommender.project")

  -- Scope support -------------------------------------------------------------
  -- Every non-buffer scope ends up calling analyze() with an explicit `lines`
  -- array, which only the regex-based analyzers take -- treesitter reads the
  -- buffer's parse tree and has nothing to do with a list of strings.
  H.ok(project.supports_cwd("regex"), "regex supports non-buffer scopes")
  H.falsy(project.supports_cwd("treesitter"), "treesitter does not")
  H.falsy(project.supports_cwd("nonsense"), "an unknown analyzer does not")

  -- File collection -----------------------------------------------------------
  -- The fixture lives under TESTS/ rather than in `vim.fn.tempname()`: on
  -- Windows the temp path contains an 8.3 short component (`STEFAN~1`), and
  -- `glob()`/`globpath()` return nothing for files written beneath it -- so a
  -- tempname-based fixture would pass on Linux and silently assert nothing
  -- here. A path inside the repository has no such component on either OS.
  local root = vim.fs.normalize(vim.fn.getcwd()) .. "/TESTS/.fixture"
  vim.fn.delete(root, "rf")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.mkdir(root .. "/node_modules", "p")
  vim.fn.mkdir(root .. "/.hidden", "p")
  vim.fn.writefile({ "local x = vim.fn.getcwd()" }, root .. "/a.lua")
  vim.fn.writefile({ "local y = vim.fn.tempname()" }, root .. "/src/b.lua")
  vim.fn.writefile({ "not lua" }, root .. "/README.md")
  vim.fn.writefile({ "local z = 1" }, root .. "/node_modules/vendored.lua")
  vim.fn.writefile({ "local h = 1" }, root .. "/.hidden/dotdir.lua")

  local files, truncated = project.find_files("regex", root, {}, 100)
  H.eq(#files, 3, "finds every .lua file, recursively, and nothing else")
  H.falsy(truncated, "and does not report a truncation it did not make")

  local ignored = project.find_files("regex", root, { "node_modules" }, 100)
  H.eq(#ignored, 2, "an ignored directory name drops everything under it")

  local capped, was_truncated = project.find_files("regex", root, {}, 1)
  H.eq(#capped, 1, "max_files caps the result")
  H.ok(was_truncated, "and says so, so a caller can tell the user")

  H.eq(#project.find_files("nonsense", root, {}, 0), 0, "an unknown analyzer collects nothing")

  -- Async file collection -------------------------------------------------------
  -- Same fixture, same expected results as the sync `find_files` block above --
  -- `find_files_async` (what `:Recommender cwd`/`path` actually calls now, see
  -- bindings/usrcmds.lua) walks via `vim.uv.fs_scandir` instead of one
  -- `globpath()` call, and the two must agree on what counts as "found".
  do
    ---@param analyzer_name string
    ---@param ignore string[]
    ---@param max_files integer
    ---@return string[], boolean
    local function find_files_async_sync(analyzer_name, ignore, max_files)
      local done = false
      ---@type string[]
      local result = {}
      local result_truncated = false
      project.find_files_async(analyzer_name, root, ignore, max_files, {
        on_done = function(found, is_truncated)
          result, result_truncated, done = found, is_truncated, true
        end,
      })
      H.wait_until(function()
        return done
      end, "find_files_async never called on_done")
      return result, result_truncated
    end

    local async_files = find_files_async_sync("regex", {}, 100)
    H.eq(#async_files, 3, "same 3 files as the sync scan")

    -- `find_files_async` builds paths as `dir .. "/" .. name` (uv-style,
    -- always forward slashes); `find_files` returns whatever `globpath()`
    -- hands back (native separators, backslashes on Windows). Neither
    -- Neovim nor this plugin cares which one a path string uses (`is_ignored`
    -- already splits on `[/\\]`; `vim.fn.readfile` takes either on Windows),
    -- so the comparison normalizes before asserting instead of forcing one
    -- implementation to mimic the other's separator convention.
    local function normalized(list)
      local out = {}
      for i, p in ipairs(list) do
        out[i] = vim.fs.normalize(p)
      end
      table.sort(out)
      return out
    end
    local sync_files = project.find_files("regex", root, {}, 100)
    H.eq(
      table.concat(normalized(async_files), "|"),
      table.concat(normalized(sync_files), "|"),
      "same file list, modulo path separator style"
    )

    -- The fixture's `.hidden/dotdir.lua` must never surface: `find_files`
    -- (sync) never finds it either, because `globpath()`'s `**` wildcard does
    -- not descend into dotdirectories -- `find_files_async` has to replicate
    -- that on purpose (see project.lua), not just "happen" to match here.
    H.falsy(
      vim.tbl_contains(normalized(async_files), vim.fs.normalize(root .. "/.hidden/dotdir.lua")),
      "a dotdirectory's contents are skipped"
    )

    local async_ignored = find_files_async_sync("regex", { "node_modules" }, 100)
    H.eq(#async_ignored, 2, "an ignored directory name drops everything under it here too")

    local async_capped, async_truncated = find_files_async_sync("regex", {}, 1)
    H.eq(#async_capped, 1, "max_files caps the result here too")
    H.ok(async_truncated, "and says so")

    H.eq(#find_files_async_sync("nonsense", {}, 0), 0, "an unknown analyzer collects nothing here too")
  end

  -- is_cancelled stops the walk before it ever calls on_done -- same
  -- supersession contract as read_lines_async, checked here against the
  -- walk instead of the read.
  do
    local saw_a_directory = false
    local on_done_called = false
    project.find_files_async("regex", root, {}, 0, {
      is_cancelled = function()
        return saw_a_directory
      end,
      on_progress = function()
        saw_a_directory = true
      end,
      on_done = function()
        on_done_called = true
      end,
    })

    H.wait_until(function()
      return saw_a_directory
    end, "the walk never scanned even the root directory")

    vim.wait(50)
    H.falsy(on_done_called, "cancelling mid-walk must stop it before on_done")
  end

  -- Reading -------------------------------------------------------------------
  local lines = project.read_lines({ root .. "/a.lua", root .. "/src/b.lua" })
  H.eq(#lines, 2, "one entry per line across all files")
  H.ok(vim.tbl_contains(lines, "local x = vim.fn.getcwd()"), "the file contents come through unchanged")

  -- A path that does not exist is skipped rather than raising: a project scan
  -- races against the filesystem, and one deleted file must not lose the run.
  local partial = project.read_lines({ root .. "/a.lua", root .. "/gone.lua" })
  H.eq(#partial, 1, "a missing file is skipped, not fatal")

  -- Async reading -------------------------------------------------------------
  -- Same content as the sync `read_lines` above, but delivered through
  -- `vim.schedule` batches -- what `:Recommender cwd`/`path` actually calls
  -- now (see bindings/usrcmds.lua) so the editor stays responsive on a large
  -- scan. `batch_size = 1` forces multiple batches even over these two tiny
  -- fixture files, so the test exercises the "yield between batches" path,
  -- not just the "everything fits in one batch" shortcut.
  do
    local async_lines, progress_calls = nil, {}
    project.read_lines_async({ root .. "/a.lua", root .. "/src/b.lua" }, {
      batch_size = 1,
      on_progress = function(done, total)
        progress_calls[#progress_calls + 1] = { done = done, total = total }
      end,
      on_done = function(result)
        async_lines = result
      end,
    })
    H.falsy(async_lines, "on_done has not run yet -- read_lines_async must not block the caller")

    H.wait_until(function()
      return async_lines ~= nil
    end, "read_lines_async never called on_done")

    H.eq(#async_lines, 2, "same result as the sync read_lines, over two batches")
    H.ok(vim.tbl_contains(async_lines, "local x = vim.fn.getcwd()"), "file contents come through unchanged")
    H.eq(#progress_calls, 2, "one on_progress call per batch (batch_size=1, two files)")
    H.eq(progress_calls[2].done, 2, "the final progress call reports every file done")
    H.eq(progress_calls[2].total, 2, "...against the correct total")
  end

  -- is_cancelled, checked before every batch, stops the scan silently: no
  -- further batches run and on_done is never called -- this is what lets a
  -- superseded `:Recommender` invocation's stale scan (another invocation,
  -- or an ignore/un-ignore refresh -- see the module-level `_scan_generation`
  -- in bindings/usrcmds.lua) abandon itself instead of racing to open a float.
  do
    local cancelled_after_first_batch = false
    local on_done_called = false
    project.read_lines_async({ root .. "/a.lua", root .. "/src/b.lua" }, {
      batch_size = 1,
      is_cancelled = function()
        return cancelled_after_first_batch
      end,
      on_progress = function()
        cancelled_after_first_batch = true
      end,
      on_done = function()
        on_done_called = true
      end,
    })

    H.wait_until(function()
      return cancelled_after_first_batch
    end, "the first batch never ran")

    -- Give a would-be second batch a chance to run (it must not).
    vim.wait(50)
    H.falsy(on_done_called, "cancelling after the first batch must stop the scan before on_done")
  end

  vim.fn.delete(root, "rf")
end

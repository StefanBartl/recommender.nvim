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
  vim.fn.writefile({ "local x = vim.fn.getcwd()" }, root .. "/a.lua")
  vim.fn.writefile({ "local y = vim.fn.tempname()" }, root .. "/src/b.lua")
  vim.fn.writefile({ "not lua" }, root .. "/README.md")
  vim.fn.writefile({ "local z = 1" }, root .. "/node_modules/vendored.lua")

  local files, truncated = project.find_files("regex", root, {}, 100)
  H.eq(#files, 3, "finds every .lua file, recursively, and nothing else")
  H.falsy(truncated, "and does not report a truncation it did not make")

  local ignored = project.find_files("regex", root, { "node_modules" }, 100)
  H.eq(#ignored, 2, "an ignored directory name drops everything under it")

  local capped, was_truncated = project.find_files("regex", root, {}, 1)
  H.eq(#capped, 1, "max_files caps the result")
  H.ok(was_truncated, "and says so, so a caller can tell the user")

  H.eq(#project.find_files("nonsense", root, {}, 0), 0, "an unknown analyzer collects nothing")

  -- Reading -------------------------------------------------------------------
  local lines = project.read_lines({ root .. "/a.lua", root .. "/src/b.lua" })
  H.eq(#lines, 2, "one entry per line across all files")
  H.ok(vim.tbl_contains(lines, "local x = vim.fn.getcwd()"), "the file contents come through unchanged")

  -- A path that does not exist is skipped rather than raising: a project scan
  -- races against the filesystem, and one deleted file must not lose the run.
  local partial = project.read_lines({ root .. "/a.lua", root .. "/gone.lua" })
  H.eq(#partial, 1, "a missing file is skipped, not fatal")

  vim.fn.delete(root, "rf")
end

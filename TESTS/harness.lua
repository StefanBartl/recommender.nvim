-- TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Assert a falsy value.
---@param v any
---@param msg string|nil
function H.falsy(v, msg)
  if v then
    error(("FAIL %s: expected falsy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Look up one suggestion by its chain, so a spec never depends on result order
--- beyond what it is explicitly asserting.
---@param results {chain:string, count:integer, alias:string}[]
---@param chain string
---@return {chain:string, count:integer, alias:string}|nil
function H.find(results, chain)
  for _, r in ipairs(results) do
    if r.chain == chain then
      return r
    end
  end
  return nil
end

--- Fresh scratch buffer, made current, filled with `lines`.
---@param lines string[]
---@return integer bufnr
function H.scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

--- Pump the event loop (via `vim.wait`) until `predicate()` is truthy, or
--- fail with a descriptive error once `timeout_ms` elapses. For code that
--- finishes via `vim.schedule` chains (e.g. `project.read_lines_async`)
--- rather than returning a value directly.
---@param predicate fun(): boolean
---@param msg string|nil
---@param timeout_ms integer|nil  default 2000
function H.wait_until(predicate, msg, timeout_ms)
  local ok = vim.wait(timeout_ms or 2000, predicate, 5)
  if not ok then
    error(("FAIL %s: condition never became true within %dms"):format(msg or "", timeout_ms or 2000), 2)
  end
end

return H

---@module 'recommender.analyzers.perf'
---@brief Detects Lua performance anti-patterns with a measured, benchmarked
---win — not dotted-chain repetition like the other analyzers.
---@description
--- Four fixed patterns, each backed by a concrete benchmark (see
--- docs/FEATURES.md#perf-analyzer): `table.insert` in a loop (~4-5x slower
--- than indexed assignment), a self-referential `x = x .. y` concat
--- accumulator in a loop (O(n^2) vs `table.concat`'s O(n)), an `ipairs`
--- loop (~2x slower than a numeric `for`), and `string.format` in a loop
--- (~3x slower than `..`). Deliberately narrow: dotted-chain aliasing
--- (regex/treesitter/javascript/python) turned out to have no measurable
--- win under LuaJIT (Neovim's runtime) — see the same doc section — so this
--- analyzer only reports cases with an actual, verified benefit.
---
--- table.insert/string.format/the concat accumulator only count within a
--- loop body (for/while/repeat) — outside a loop, a single extra call is
--- nanoseconds and not worth flagging. A lightweight line-based block
--- tracker (`classify_line`) maintains a loop/non-loop stack; `ipairs` is
--- flagged on its own `for ... in ipairs(...)` line regardless of nesting,
--- since the per-iteration cost applies independent of surrounding loops.

local blacklist = require("recommender.blacklist")

local M = {}

---Fixed rewrite tips, inserted verbatim as a comment when a suggestion is
---accepted (Enter/A). Advisory only — the concrete rewrite depends on
---variable names/context this analyzer can't safely infer, so nothing is
---auto-rewritten.
---@type table<string, string>
local TIPS = {
  ["table.insert(...)"] = "-- perf: table.insert(t, v) in a loop is ~4-5x slower than t[#t+1] = v or t[i] = v (indexed assignment)",
  ["ipairs(...)"] = "-- perf: ipairs() loop is ~2x slower than 'for i = 1, #t do' -- prefer the numeric form in hot loops",
  ["x = x .. y (concat accumulator)"] = "-- perf: a self-concat accumulator in a loop is O(n^2) -- collect pieces in a table and table.concat() once instead",
  ["string.format(...)"] = "-- perf: string.format() in a loop is ~3x slower than '..' concatenation -- reserve it for one-off formatting",
}

---Iteration order for the result list (counts decide final sort; this only
---seeds a stable key set).
---@type string[]
local KEYS = { "table.insert(...)", "ipairs(...)", "x = x .. y (concat accumulator)", "string.format(...)" }

---@internal
---Grab the last "word" of a trimmed line, ignoring trailing punctuation
---like `)`, `,`, `}` (common after `end)`, `end,`, `end}` in callback/table
---contexts).
---@param trimmed string
---@return string|nil
local function last_word(trimmed)
  return trimmed:match("([%w_]+)%s*[%)%,%}]*$")
end

---@internal
---Classify one line for the loop-nesting stack.
---@param line string
---@return "open"|"close"|"single"|"content" kind
---@return boolean|nil is_loop  meaningful only for "open"/"single"
local function classify_line(line)
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return "content", nil
  end

  local lw = last_word(trimmed)

  if lw == "end" then
    -- Single-line block: opens and closes on the same physical line, net
    -- depth 0 (e.g. `for i=1,3 do print(i) end`, `if x then return end`).
    local body = trimmed:match("^(.-)%send$") or trimmed
    if body:find("%sdo%s") or body:find("^do%s") then
      local is_loop = body:match("^for%f[%s]") ~= nil or body:match("^while%f[%s]") ~= nil
      return "single", is_loop
    end
    if body:find("%sthen%s") then
      return "single", false
    end
    return "close", nil
  end

  if lw == "then" then
    if trimmed:match("^elseif%f[%s]") then
      return "content", nil -- continuation of the enclosing if, no new depth
    end
    return "open", false
  end

  if lw == "do" then
    local is_loop = trimmed:match("^for%f[%s]") ~= nil or trimmed:match("^while%f[%s]") ~= nil
    return "open", is_loop
  end

  if trimmed == "repeat" or trimmed:match("^repeat%f[%s]") then
    return "open", true
  end

  if trimmed:match("^until%f[%s]") or trimmed == "until" then
    return "close", nil
  end

  return "content", nil
end

---Analyze a buffer (or an explicit line list) for the four anti-patterns.
---@param threshold integer
---@param custom_aliases table<string,string>  Optional per-pattern override for the inserted tip text.
---@param bl string[]
---@param lines string[]|nil  Explicit lines to scan; defaults to the current buffer's lines when omitted.
---@return {chain:string, count:integer, alias:string}[]
function M.analyze(threshold, custom_aliases, bl, lines)
  lines = lines or vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local counts = {}

  -- One frame per open block: whether it is a loop, and the `local` names
  -- declared directly in it. The names are what tell an accumulator apart
  -- from a variable that merely looks like one -- see `declared_in_loop`.
  ---@type { is_loop: boolean, locals: table<string, true> }[]
  local stack = {}

  local function in_loop()
    for _, frame in ipairs(stack) do
      if frame.is_loop then
        return true
      end
    end
    return false
  end

  ---Whether `name` was declared with `local` inside the innermost enclosing
  ---loop (or deeper). Such a variable is re-created on every iteration, so
  ---`name = name .. y` appends to a fresh string each time and cannot grow
  ---quadratically -- it is not an accumulator, whatever the line looks like.
  ---
  ---This is the shape that produced every false positive found when the
  ---analyzer was first run across a real config: `local ident = f(node)`
  ---followed by `ident = ident .. "()"`, three times out of three findings.
  ---@param name string
  ---@return boolean
  local function declared_in_loop(name)
    for i = #stack, 1, -1 do
      if stack[i].locals[name] then
        return true
      end
      if stack[i].is_loop then
        return false
      end
    end
    return false
  end

  for _, line in ipairs(lines) do
    local kind, is_loop = classify_line(line)

    local scanning_in_loop = (kind == "single" and is_loop) or in_loop()

    if (kind == "content" or kind == "single") and scanning_in_loop then
      if line:find("table%.insert%s*%(") then
        counts["table.insert(...)"] = (counts["table.insert(...)"] or 0) + 1
      end
      if line:find("string%.format%s*%(") then
        counts["string.format(...)"] = (counts["string.format(...)"] or 0) + 1
      end
      -- Anchored to the start of the line, so a table field reading an outer
      -- variable of the same name is not mistaken for an assignment to it:
      -- `{ short = short, dir = dir .. "/" .. short }` matched the unanchored
      -- form, and `dir` there is a key, not the target.
      local accum = line:match("^%s*([%w_%.]+)%s*=%s*[%w_%.]+%s*%.%.")
      if accum and line:match("^%s*([%w_%.]+)%s*=%s*(%1)%s*%.%.") and not declared_in_loop(accum) then
        counts["x = x .. y (concat accumulator)"] = (counts["x = x .. y (concat accumulator)"] or 0) + 1
      end
    end

    if line:find("for%s+[%w_,%s]+%s+in%s+ipairs%s*%(") then
      counts["ipairs(...)"] = (counts["ipairs(...)"] or 0) + 1
    end

    -- Recorded before the block bookkeeping below, so a `local` on the same
    -- line as the block opener (`for ... do local x = ...` is rare but legal)
    -- lands in the frame it belongs to on the next line either way.
    local declared = line:match("^%s*local%s+([%w_]+)")
    if declared and #stack > 0 then
      stack[#stack].locals[declared] = true
    end

    if kind == "open" then
      stack[#stack + 1] = { is_loop = is_loop, locals = {} }
    elseif kind == "close" then
      stack[#stack] = nil
    end
  end

  local res = {}
  for _, key in ipairs(KEYS) do
    local count = counts[key] or 0
    if count >= threshold and not blacklist.is_blacklisted(key, bl) then
      local alias = (custom_aliases and custom_aliases[key]) or TIPS[key]
      res[#res + 1] = { chain = key, count = count, alias = alias }
    end
  end

  table.sort(res, function(a, b)
    return a.count > b.count
  end)
  return res
end

return M

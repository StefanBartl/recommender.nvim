---@module 'recommender.analyzers.perf'
---@brief Detects Lua performance anti-patterns with a measured, benchmarked
---win — not dotted-chain repetition like the other analyzers.
---@description
--- Four fixed patterns, each backed by a concrete benchmark (see
--- docs/FEATURES.md#perf-analyzer): `table.insert` in a loop (~4-5x slower
--- than indexed assignment; the three-argument insert at a position is not reported), a self-referential `x = x .. y` concat
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
  ["string.format(...)"] = "-- perf: string.format() in a loop is ~3x slower than '..' concatenation -- only a plain join is equivalent (not %5.2f or many operands), so reserve it for one-off formatting",
}

---Iteration order for the result list (counts decide final sort; this only
---seeds a stable key set).
---@type string[]
local KEYS = { "table.insert(...)", "ipairs(...)", "x = x .. y (concat accumulator)", "string.format(...)" }

---@internal
---Number of top-level arguments of the call whose `(` is at `open`, or nil when
---the call does not close on this line (a multi-line call cannot be counted).
---Brackets, braces and quoted strings are skipped, so a comma inside a table
---constructor or a string does not split an argument.
---@param line string
---@param open integer  index of the `(`
---@return integer|nil
local function call_arg_count(line, open)
  local depth, args, quote = 0, 1, nil
  local i = open
  while i <= #line do
    local c = line:sub(i, i)
    if quote then
      if c == "\\" then
        i = i + 1
      elseif c == quote then
        quote = nil
      end
    elseif c == '"' or c == "'" then
      quote = c
    elseif c == "(" or c == "{" or c == "[" then
      depth = depth + 1
    elseif c == ")" or c == "}" or c == "]" then
      depth = depth - 1
      if depth == 0 then
        return args
      end
    elseif c == "," and depth == 1 then
      args = args + 1
    end
    i = i + 1
  end
  return nil
end

---@internal
---Whether `line` has a `table.insert(t, v)` that appends. The three-argument
---`table.insert(t, pos, v)` shifts the elements behind `pos`, which indexed
---assignment cannot replace, so it is not what the tip is about. A call that
---does not close on the line is counted: it is the common form and the tip is
---advisory.
---@param line string
---@return boolean
local function has_append_insert(line)
  local from = 1
  while true do
    local s, e = line:find("table%.insert%s*%(", from)
    if not s then
      return false
    end
    if call_arg_count(line, e) ~= 3 then
      return true
    end
    from = e + 1
  end
end

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

---@internal
---Net change of table-constructor depth over `line`: `{` minus `}`, skipping
---quoted strings, `--` comments and long brackets (`[[ ]]`, `[==[ ]==]`,
---`--[[ ]]`). A long bracket left open at the end of the line is returned as
---its closing delimiter and passed back in for the next line, so a brace in a
---multi-line long string or block comment never shifts the depth.
---@param line string
---@param long_close string|nil  Closing delimiter of a long bracket open from an earlier line.
---@return integer delta
---@return string|nil long_close  Closing delimiter still open at the end of `line`.
local function brace_delta(line, long_close)
  local delta, quote = 0, nil
  local i = 1
  if long_close then
    local _, e = line:find(long_close, 1, true)
    if not e then
      return 0, long_close
    end
    i = e + 1
  end
  while i <= #line do
    local c = line:sub(i, i)
    if quote then
      if c == "\\" then
        i = i + 1
      elseif c == quote then
        quote = nil
      end
    elseif c == '"' or c == "'" then
      quote = c
    else
      local comment = c == "-" and line:sub(i + 1, i + 1) == "-"
      local open = line:match("^%[(=*)%[", comment and i + 2 or i)
      if open then
        local close = "]" .. open .. "]"
        local _, e = line:find(close, (comment and i + 2 or i) + #open + 2, true)
        if not e then
          return delta, close
        end
        i = e
      elseif comment then
        break
      elseif c == "{" then
        delta = delta + 1
      elseif c == "}" then
        delta = delta - 1
      end
    end
    i = i + 1
  end
  return delta, nil
end

---@internal
---Names a `for` header introduces: the targets of `for a, b in ...` or the
---counter of `for i = ...`. Each is a fresh binding per iteration, exactly like
---a `local` declared in the loop body.
---@param line string
---@return string[]
local function loop_header_vars(line)
  local list = line:match("^%s*for%s+([%w_,%s]-)%s+in%f[%s]")
  if not list then
    local counter = line:match("^%s*for%s+([%w_]+)%s*=")
    return counter and { counter } or {}
  end
  local names = {}
  for name in list:gmatch("[%w_]+") do
    names[#names + 1] = name
  end
  return names
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
  -- `braces` is the table-constructor depth at the start of the current line;
  -- each frame remembers the depth its body starts at (after the opener line),
  -- so a line deeper than its
  -- innermost frame sits inside a (multi-line) constructor: `dir = dir .. x`
  -- there is a field, not an assignment.
  ---@type { is_loop: boolean, locals: table<string, true>, braces: integer }[]
  local stack = {}
  local braces = 0
  ---@type string|nil  closing delimiter of a long string/comment spanning lines
  local long_close = nil

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
  ---
  ---A dotted target (`d.message = d.message .. y`) is judged by its root name:
  ---a fresh `d` per iteration means a fresh field, too.
  ---@param name string
  ---@return boolean
  local function declared_in_loop(name)
    name = name:match("^[%w_]+") or name
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
    local delta
    delta, long_close = brace_delta(line, long_close)
    local braces_after = math.max(0, braces + delta)

    local scanning_in_loop = (kind == "single" and is_loop) or in_loop()

    if (kind == "content" or kind == "single") and scanning_in_loop then
      if has_append_insert(line) then
        counts["table.insert(...)"] = (counts["table.insert(...)"] or 0) + 1
      end
      if line:find("string%.format%s*%(") then
        counts["string.format(...)"] = (counts["string.format(...)"] or 0) + 1
      end
      -- Anchored to the start of the line, so a table field reading an outer
      -- variable of the same name is not mistaken for an assignment to it:
      -- `{ short = short, dir = dir .. "/" .. short }` matched the unanchored
      -- form, and `dir` there is a key, not the target.
      -- The anchor alone cannot see a multi-line constructor (one field per
      -- line), hence the brace depth against the innermost frame.
      local in_constructor = braces > (#stack > 0 and stack[#stack].braces or 0)
      local accum = not in_constructor and line:match("^%s*([%w_%.]+)%s*=%s*[%w_%.]+%s*%.%.")
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
      -- `classify` answers with a boolean for "open"/"single" and nil for the
      -- kinds where the question does not apply; this is the "open" branch.
      ---@cast is_loop boolean
      -- The depth after the opener line is the body's base: `}) do` closes a
      -- multi-line iteration literal (`for _, v in ipairs({ ... }) do`) on the
      -- very line that opens the block.
      local frame = { is_loop = is_loop, locals = {}, braces = braces_after }
      if is_loop then
        for _, name in ipairs(loop_header_vars(line)) do
          frame.locals[name] = true
        end
      end
      stack[#stack + 1] = frame
    elseif kind == "close" then
      stack[#stack] = nil
    end

    braces = braces_after
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

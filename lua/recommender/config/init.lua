---@module 'recommender.config'
---@brief Runtime configuration store for recommender.nvim.
---@description
--- Merges user options over the immutable DEFAULTS and exposes the active
--- config via `get()`. `bindings/usrcmds.lua` captures `get()`'s table once
--- (in the `:Recommender` command's `run` closure) and reads fields from it
--- on every invocation, so a re-`setup()` mutates that table in place
--- rather than replacing it — otherwise that captured reference would
--- silently decouple from whatever `setup()` was called with the second
--- time.

local DEFAULTS = require("recommender.config.DEFAULTS")

local M = {}

---@type Recommender.Config
local _active = vim.deepcopy(DEFAULTS)

---Issues found by the last `setup()` call (unknown keys, rejected values),
---for `:checkhealth`. Empty when the config was clean.
---@type string[]
local _issues = {}

---@type string[]
local PROGRESS_STYLES = { "auto", "notify", "statusline", "fidget", "float", "kit" }
---@type string[]
local FLOAT_LAYOUTS = { "detailed", "compact" }

-- Known top-level keys, kept in sync with `@types.lua`'s `Recommender.Config`.
-- `keymaps`/`float_keymaps` are leaves here (boolean|table) — their
-- per-action shape is validated by `lib.nvim.bindings.keymap`'s registry
-- itself, which already reports an unrecognized action name on its own.
---@type table<string, boolean>
local SCHEMA = {
  analyzer = true,
  threshold = true,
  custom_aliases = true,
  blacklist = true,
  keymaps = true,
  cwd_ignore = true,
  cwd_max_files = true,
  progress_style = true,
  float_layout = true,
  float_keymaps = true,
}

---@internal
---Nearest known key to `key`, as a hint, or nil when nothing is close enough
---to be a plausible typo.
---@param key string
---@return string|nil
local function suggest(key)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local best, best_d = nil, nil
  for k in pairs(SCHEMA) do
    local d = levenshtein(key, k)
    if d <= 3 and (best_d == nil or d < best_d) then
      best, best_d = k, d
    end
  end
  return best
end

---@internal
---Drop, in place, any key `opts` has that `SCHEMA` doesn't — recording one
---issue per drop.
---@param opts table
---@param issues string[]
local function drop_unknown(opts, issues)
  for key in pairs(opts) do
    if not SCHEMA[key] then
      local hint = type(key) == "string" and suggest(key)
      issues[#issues + 1] = hint and ("unknown option %q (did you mean %q?)"):format(tostring(key), hint)
        or ("unknown option %q"):format(tostring(key))
      opts[key] = nil
    end
  end
end

---@internal
---Reject an `analyzer` naming no `recommender.analyzers.*` module, degrading
---to the default (ERR-22) rather than letting the typo reach `get_analyzer`
---unchallenged — same "does the module actually exist" test
---`recommender.statusline` already uses, so the accepted set can never drift
---out of sync with the `analyzers/` directory.
---@param opts table
---@param issues string[]
local function validate_analyzer(opts, issues)
  local v = opts.analyzer
  if v == nil then
    return
  end
  local ok = type(v) == "string" and pcall(require, "recommender.analyzers." .. v)
  if not ok then
    issues[#issues + 1] = ("analyzer %q is not a known analyzer; using default %q"):format(tostring(v), DEFAULTS.analyzer)
    opts.analyzer = nil
  end
end

---@internal
---Reject a value not in `values` for `field`, degrading to the default.
---@param opts table
---@param field string
---@param values string[]
---@param issues string[]
local function validate_enum(opts, field, values, issues)
  local v = opts[field]
  if v == nil then
    return
  end
  if not vim.tbl_contains(values, v) then
    issues[#issues + 1] = ("%s %q is not one of %s; using default %q"):format(
      field,
      tostring(v),
      table.concat(values, ", "),
      tostring(DEFAULTS[field])
    )
    opts[field] = nil
  end
end

---@internal
---Copy `src` into `dst` in place: a sub-table `dst` already has keeps its
---identity, only its contents change. `bindings/usrcmds.lua` captures
---`M.get()`'s table in the `:Recommender` command's `run` closure for the
---rest of the session — replacing it wholesale on a second `setup()` would
---silently decouple that closure from the new values (ERR-53).
---@param dst table
---@param src table
local function deep_assign(dst, src)
  for k in pairs(dst) do
    if src[k] == nil then
      dst[k] = nil
    end
  end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deep_assign(dst[k], v)
    else
      dst[k] = v
    end
  end
end

---Merge user options over the defaults and store the result. Unknown keys
---(typos included) and an invalid `analyzer`/`progress_style`/`float_layout`
---are reported here, before the merge, and dropped rather than silently
---kept — see `M.issues()`.
---@param opts Recommender.Config|nil
---@return Recommender.Config
function M.setup(opts)
  local issues = {}
  local incoming = (type(opts) == "table") and vim.deepcopy(opts) or {}

  drop_unknown(incoming, issues)
  validate_analyzer(incoming, issues)
  validate_enum(incoming, "progress_style", PROGRESS_STYLES, issues)
  validate_enum(incoming, "float_layout", FLOAT_LAYOUTS, issues)
  _issues = issues

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), incoming)
  deep_assign(_active, merged)
  return _active
end

---@return Recommender.Config
function M.get()
  return _active
end

---Validation issues from the last `setup()` call (unknown keys, rejected
---values), for `:checkhealth`. Empty when the config was clean.
---@return string[]
function M.issues()
  return _issues
end

return M

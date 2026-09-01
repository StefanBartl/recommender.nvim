---@module 'recommender.bindings.usrcmds'
---@brief The `:Recommender` user command, built via lib.nvim.bindings.usercmd.composer.
---@description
--- Parses flags/positional args, resolves the analyzer + threshold + scope,
--- and owns the per-invocation state passed to `recommender.float.keymaps`.
---
--- execute() is the dispatch engine (state/refresh/rendering logic). The one
--- composer route is a `path = {}` root route — this grammar has no
--- subcommand word at all — declaring `flags = {{name="replace", short="r",
--- bool=true}, {name="cwd", short="c", bool=true}}` (Phase 7's short-flag
--- alias, added specifically to unblock this repo) and three optional
--- positional slots. Composer's flag/positional split is the same algorithm
--- the original inline loop used (strip -r/--replace tokens, keep the rest
--- in order), so ctx.flags.replace / ctx.pos feed execute() directly — no
--- reconstruction needed.
---
--- Scope (`buffer` (default) | `path` | `cwd` | `cfile` | `line`) is a plain
--- positional value, classified by content rather than by slot position —
--- `classify_pos_args()` scans every leftover token and buckets it as a
--- scope, analyzer, or threshold match regardless of where it appears, so
--- `:Recommender cwd javascript 5`, `:Recommender javascript cwd 5`, and
--- `:Recommender 5 javascript cwd` all resolve identically. `-c`/`--cwd`
--- (see `recommender.project`) is kept as a backward-compatible alias for
--- `scope = "cwd"`; an explicit scope positional always wins over it.

local composer = require("lib.nvim.bindings.usercmd.composer")

local rendering = require("recommender.float.rendering")
local keymaps_m = require("recommender.float.keymaps")
local project = require("recommender.project")
local notify = require("recommender.util.notify").create("[recommender]")

local M = {}

local api = vim.api

---Names accepted for `{analyzer}` positional args and `config.analyzer`.
---@type string[]
local ANALYZER_NAMES = { "regex", "treesitter", "javascript", "python", "perf" }

---@type table<string, boolean>
local _is_analyzer_name = {}
for _, name in ipairs(ANALYZER_NAMES) do
  _is_analyzer_name[name] = true
end

---Names accepted for the `{scope}` positional arg. `"buffer"` is the
---default and never needs to be typed; it's listed so `:Recommender buffer`
---works as an explicit no-op.
---@type string[]
local SCOPE_NAMES = { "buffer", "path", "cwd", "cfile", "line" }

---@type table<string, boolean>
local _is_scope_name = {}
for _, name in ipairs(SCOPE_NAMES) do
  _is_scope_name[name] = true
end

---Title suffix per non-default scope; `"buffer"` gets none.
---@type table<string, string>
local SCOPE_LABEL = { cwd = "PROJECT", path = "PATH", cfile = "CFILE", line = "LINE" }

---Positional-value completion hints: either an analyzer name or a scope
---name may land in any of the three positional slots (see `classify_pos_args`).
---@type string[]
local COMPLETION_VALUES = {}
for _, name in ipairs(ANALYZER_NAMES) do
  COMPLETION_VALUES[#COMPLETION_VALUES + 1] = name
end
for _, name in ipairs(SCOPE_NAMES) do
  COMPLETION_VALUES[#COMPLETION_VALUES + 1] = name
end

---Analyzer names that support non-buffer scope (see `project.supports_cwd`),
---computed once so the error message below can never drift out of sync with
---`project.lua`'s actual EXTENSIONS table.
---@type string
local NON_BUFFER_CAPABLE_ANALYZERS = (function()
  local names = {}
  for _, name in ipairs(ANALYZER_NAMES) do
    if project.supports_cwd(name) then
      names[#names + 1] = name
    end
  end
  return table.concat(names, ", ")
end)()

---@type table<string, table>
local _analyzer_cache = {}

---@internal
---Load an analyzer backend by name, with error propagation.
---Results are cached so the module is only required once per session.
---@param name "regex"|"treesitter"|"javascript"|"python"|"perf" One of `ANALYZER_NAMES` above, which is what the command line validates against.
---@return table
local function get_analyzer(name)
  if _analyzer_cache[name] then
    return _analyzer_cache[name]
  end
  local mod_name = "recommender.analyzers." .. name
  local ok, mod = pcall(require, mod_name)
  if not ok then
    error(("[recommender] Unknown analyzer %q — expected one of: %s"):format(name, table.concat(ANALYZER_NAMES, ", ")), 2)
  end
  _analyzer_cache[name] = mod
  return mod
end

---@internal
---Classify leftover positional tokens by content, not by slot position —
---each token is checked against the scope names, then the analyzer names,
---then `tonumber`. The first match for each category wins, so token order
---never matters: `cwd javascript 5`, `javascript cwd 5`, and `5 javascript
---cwd` all classify identically.
---@param pos_args string[]
---@return string|nil analyzer_name
---@return integer|nil threshold
---@return string|nil scope
local function classify_pos_args(pos_args)
  local analyzer_name, threshold, scope
  for _, tok in ipairs(pos_args) do
    if not scope and _is_scope_name[tok] then
      scope = tok
    elseif not analyzer_name and _is_analyzer_name[tok] then
      analyzer_name = tok
    elseif not threshold then
      threshold = tonumber(tok)
    end
  end
  return analyzer_name, threshold, scope
end

---@internal
---Resolve `<cfile>` text to an absolute, readable file path: as typed,
---then relative to the source buffer's directory, then via the `'path'`
---option — the same resolution order `gf` effectively relies on.
---@param cfile string|nil
---@param bufnr integer
---@return string|nil path
---@return string|nil err
local function resolve_cfile(cfile, bufnr)
  if not cfile or cfile == "" then
    return nil, "no file name under the cursor"
  end

  if vim.fn.filereadable(cfile) == 1 then
    return vim.fn.fnamemodify(cfile, ":p"), nil
  end

  local bufname = api.nvim_buf_get_name(bufnr)
  if bufname ~= "" then
    local candidate = vim.fn.fnamemodify(bufname, ":p:h") .. "/" .. cfile
    if vim.fn.filereadable(candidate) == 1 then
      return vim.fn.fnamemodify(candidate, ":p"), nil
    end
  end

  -- `findfile` answers with a list only when it is given a count; this call
  -- passes none, so the string form is what comes back.
  local found = vim.fn.findfile(cfile, vim.o.path) --[[@as string]]
  if found ~= "" and vim.fn.filereadable(found) == 1 then
    return vim.fn.fnamemodify(found, ":p"), nil
  end

  return nil, ("no readable file found for %q under the cursor"):format(cfile)
end

-- Per-buffer ignore state: { [bufnr] = { [chain] = true } }
local ignore_by_buf = {}

---@internal
---Run one `:Recommender` invocation: resolve analyzer/threshold/scope,
---toggle the float if already open, and (re)build the per-buffer state
---whose `refresh()` drives the suggestion list.
---@param cfg Recommender.Config
---@param replace_mode boolean
---@param pos_args string[]
---@param cwd_flag boolean  `-c`/`--cwd`; backward-compatible alias for `scope = "cwd"`, overridden by an explicit scope positional.
---@param flag_threshold integer|nil  `--threshold=N`; wins over a positional number.
---@return nil
local function execute(cfg, replace_mode, pos_args, cwd_flag, flag_threshold)
  local pos_analyzer, pos_threshold, pos_scope = classify_pos_args(pos_args)
  -- `or "regex"` mirrors config/DEFAULTS.lua: the merge always fills
  -- `analyzer`, but the option type no longer promises it now that a
  -- partial `setup({})` is legal.
  local analyzer_name = pos_analyzer or cfg.analyzer or "regex"
  local scope = pos_scope or (cwd_flag and "cwd") or "buffer"
  -- `--threshold=N` wins over a bare number. The positional form stays
  -- because it is the documented one and order-independent, but it is
  -- inferred: a token is a threshold when it is not a scope name, not an
  -- analyzer name, and `tonumber`s. That is fine when typing by hand and
  -- exactly wrong when generating the command (a keymap, another plugin),
  -- where the intent needs saying rather than inferring.
  local explicit_threshold = flag_threshold or pos_threshold
  -- A single line dedups each chain to at most one hit (see analyzers'
  -- per-line dedup), so config.threshold (>1 in practice) would make "line"
  -- scope silently report "no suggestions" every time. Default to 1 unless
  -- the caller explicitly typed a threshold.
  local threshold = explicit_threshold or (scope == "line" and 1) or cfg.threshold

  -- Toggle: close if already open
  if rendering.is_open() then
    rendering.close()
    return
  end

  local bufnr = api.nvim_get_current_buf()
  ignore_by_buf[bufnr] = ignore_by_buf[bufnr] or {}

  ---@type table
  local state = {
    source_bufnr = bufnr,
    ignored = ignore_by_buf[bufnr],
    custom_aliases = cfg.custom_aliases or {},
    blacklist = cfg.blacklist or {},
    replace_mode = replace_mode,
    visible = {},
    -- Captured now (invocation time), not inside refresh()'s vim.schedule,
    -- so `cfile`/`line` scope reads the cursor/file that was under it when
    -- `:Recommender` was actually called.
    cfile_raw = vim.fn.expand("<cfile>"),
    cursor_line_text = api.nvim_get_current_line(),
  }

  function state.refresh()
    local ok, err = pcall(function()
      if not (state.source_bufnr and api.nvim_buf_is_valid(state.source_bufnr)) then
        notify.warn("Source buffer is no longer valid")
        rendering.close()
        return
      end

      local analyzer = get_analyzer(analyzer_name)
      local all

      if scope == "buffer" then
        api.nvim_buf_call(state.source_bufnr, function()
          all = analyzer.analyze(threshold, state.custom_aliases, state.blacklist)
        end)
      else
        if not project.supports_cwd(analyzer_name) then
          notify.error(
            ("%s scope isn't supported for analyzer %q — use one of: %s"):format(
              scope,
              analyzer_name,
              NON_BUFFER_CAPABLE_ANALYZERS
            )
          )
          rendering.close()
          return
        end

        local lines

        if scope == "cwd" or scope == "path" then
          local root
          if scope == "cwd" then
            root = vim.fn.getcwd()
          else
            local bufname = api.nvim_buf_get_name(state.source_bufnr)
            if bufname == "" then
              notify.error("path scope requires the current buffer to have a file path")
              rendering.close()
              return
            end
            root = vim.fn.fnamemodify(bufname, ":p:h")
          end

          local paths, truncated = project.find_files(analyzer_name, root, cfg.cwd_ignore, cfg.cwd_max_files)
          if #paths == 0 then
            notify.info(("No matching files found under %s"):format(root))
            rendering.close()
            return
          end
          if truncated then
            notify.warn(("%s scan capped at %d files (config.cwd_max_files)"):format(scope, cfg.cwd_max_files))
          end
          lines = project.read_lines(paths)
        elseif scope == "cfile" then
          local path, path_err = resolve_cfile(state.cfile_raw, state.source_bufnr)
          if not path then
            -- The value and the message share the call: a failure without a
            -- message would otherwise notify `nil`.
            notify.error(path_err or "no readable file under the cursor")
            rendering.close()
            return
          end
          lines = project.read_lines({ path })
        else -- "line"
          lines = { state.cursor_line_text or "" }
        end

        all = analyzer.analyze(threshold, state.custom_aliases, state.blacklist, lines)
      end

      state.visible = {}
      for _, s in ipairs(all) do
        if not state.ignored[s.chain] then
          state.visible[#state.visible + 1] = s
        end
      end

      if #state.visible == 0 then
        notify.info(("No suggestions (threshold: %d)"):format(threshold))
        rendering.close()
        return
      end

      local title = ("Recommender: %d suggestion%s"):format(#state.visible, #state.visible == 1 and "" or "s")
      if SCOPE_LABEL[scope] then
        title = title .. ("  [%s]"):format(SCOPE_LABEL[scope])
      end
      if replace_mode then
        title = title .. "  [REPLACE MODE]"
      end

      local surf = rendering.open(state.visible, title, state._restore_index, cfg.float_layout, keymaps_m.make_on_select(state))

      if surf then
        keymaps_m.attach_extra(surf.bufnr, state, cfg.float_keymaps)
      end
    end)

    if not ok then
      notify.error("Error: " .. tostring(err))
      rendering.close()
    end
  end

  vim.schedule(state.refresh)
end

---@param cfg Recommender.Config
---@return nil
function M.setup(cfg)
  composer.verb("Recommender", {
    desc = "Suggest local aliases for repeated chains. Flags: -r/--replace -c/--cwd -t/--threshold=N [analyzer] [threshold] [scope]",
    routes = {
      {
        path = {},
        args = {
          { name = "a1", type = "STRING", values = COMPLETION_VALUES, optional = true },
          { name = "a2", type = "STRING", values = COMPLETION_VALUES, optional = true },
          { name = "a3", type = "STRING", values = COMPLETION_VALUES, optional = true },
        },
        flags = {
          { name = "replace", short = "r", bool = true },
          { name = "cwd", short = "c", bool = true },
          { name = "threshold", short = "t", type = "INT" },
        },
        run = function(ctx)
          execute(cfg, ctx.flags.replace or false, ctx.pos, ctx.flags.cwd or false, ctx.flags.threshold)
        end,
      },
    },
  })
end

return M

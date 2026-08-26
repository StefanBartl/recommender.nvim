---@module 'recommender.bindings.keymaps'
---@brief Global keymaps installed by `setup()` unless `config.keymaps == false`.
---@description
--- Maps straight onto `:Recommender` invocations -- no `<Plug>` indirection.
---
--- Declared through `lib.nvim.bindings.keymap`'s registry, which is what makes
--- each one individually overridable: `keymaps` used to be a boolean, so a
--- user whose `<leader>lr` was taken could only have all eight or none.
--- `keymaps = { regex = "<leader>zr" }` now moves exactly one, `= false` drops
--- one, and `keymaps = false` still binds nothing at all. A wrong action name
--- is reported instead of silently binding nothing.
---
--- which-key needs no per-key registration: it reads the mappings and their
--- `desc` itself. Only the `<leader>lr` group label comes from the spec.
---
--- **A count sets the threshold.** `3<leader>lrr` runs the regex analyzer
--- with `--threshold=3`. Without a count nothing changes, so every mapping
--- behaves exactly as it did before.
---
--- That is why these are functions rather than `<cmd>...<cr>` strings: a
--- `<cmd>` mapping swallows the count prefix, and there is no way to read it
--- back afterwards.

local M = {}

---Build the rhs for one `:Recommender` invocation, honouring a count.
---
--- `raw()` rather than `get()`: 0 has to stay distinguishable from "the user
--- typed a count", since no count means "use the configured threshold" and
--- not "use 1".
---@internal
---@param args string  extra arguments, e.g. "regex" or "-r"
---@return fun(): nil
local function run(args)
  return function()
    local count = require("lib.nvim.count").raw()
    local cmd = "Recommender"
    if args ~= "" then
      cmd = cmd .. " " .. args
    end
    if count > 0 then
      cmd = cmd .. " --threshold=" .. count
    end
    vim.cmd(cmd)
  end
end

---Declare and bind the global keymaps.
---@param user table|boolean|nil  # `config.keymaps`
---@return Lib.Keymap.Registered[]
function M.bind(user)
  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = "<leader>lr",
    which_key = { group = "Recommender" },
    order = {
      "run",
      "replace",
      "regex",
      "treesitter",
      "javascript",
      "python",
      "high_threshold",
      "cwd",
    },
    actions = {
      run = { default = "<leader>lr", rhs = run(""), desc = "run" },
      replace = { default = "<leader>lR", rhs = run("-r"), desc = "replace mode" },
      regex = { default = "<leader>lrr", rhs = run("regex"), desc = "regex analyzer" },
      treesitter = {
        default = "<leader>lrt",
        rhs = run("treesitter"),
        desc = "treesitter analyzer",
      },
      javascript = {
        default = "<leader>lrj",
        rhs = run("javascript"),
        desc = "javascript analyzer",
      },
      python = { default = "<leader>lrp", rhs = run("python"), desc = "python analyzer" },

      -- Kept for the muscle memory, though `5<leader>lrr` now says the same
      -- thing without a dedicated key. A count on this one overrides the 5.
      high_threshold = {
        default = "<leader>lrh",
        rhs = run("regex 5"),
        desc = "regex analyzer, high threshold",
      },

      cwd = { default = "<leader>lrc", rhs = run("-c"), desc = "project-wide (cwd)" },
    },
  }

  -- `keymaps = true` says "take the defaults", which is what handing the
  -- registry no override table already says. Spelled out rather than as
  -- `cond and user or nil`: that idiom cannot carry a `false`.
  ---@type table|false|nil
  local overrides = nil
  if type(user) == "table" or user == false then
    overrides = user
  end

  return require("lib.nvim.bindings.keymap").register("Recommender", spec, overrides)
end

return M

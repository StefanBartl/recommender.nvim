---@module 'recommender.bindings.keymaps'
---@brief Global keymaps installed by `setup()` unless `config.keymaps == false`.
---@description
--- Maps straight onto `:Recommender` invocations — no `<Plug>` indirection.
--- which-key (if installed) labels the `<leader>lr` prefix via
--- `recommender.bindings.which_key`; individual key descriptions come
--- from each mapping's `desc`.
---
--- **A count sets the threshold.** `3<leader>lrr` runs the regex analyzer
--- with `--threshold=3`. Without a count nothing changes, so every mapping
--- behaves exactly as it did before.
---
--- That is why these are functions rather than `<cmd>…<cr>` strings: a
--- `<cmd>` mapping swallows the count prefix, and there is no way to read it
--- back afterwards.

local lib = require("recommender.util.lib")

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

---Bind the global keymaps.
---@return nil
function M.bind()
  lib.map("n", "<leader>lr", run(""), { desc = "Recommender" })
  lib.map("n", "<leader>lR", run("-r"), { desc = "Recommender (replace mode)" })
  lib.map("n", "<leader>lrr", run("regex"), { desc = "Recommender (regex)" })
  lib.map("n", "<leader>lrt", run("treesitter"), { desc = "Recommender (treesitter)" })
  lib.map("n", "<leader>lrj", run("javascript"), { desc = "Recommender (javascript)" })
  lib.map("n", "<leader>lrp", run("python"), { desc = "Recommender (python)" })
  -- Kept for the muscle memory, though `5<leader>lrr` now says the same thing
  -- without a dedicated key. A count on this one overrides the 5.
  lib.map("n", "<leader>lrh", run("regex 5"), { desc = "Recommender (high threshold)" })
  lib.map("n", "<leader>lrc", run("-c"), { desc = "Recommender (project-wide, cwd)" })
end

return M

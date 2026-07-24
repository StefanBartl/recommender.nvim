---@module 'recommender.bindings.keymaps'
---@brief Global keymaps installed by `setup()` unless `config.keymaps == false`.
---@description
--- Maps straight onto `:Recommender` invocations — no `<Plug>` indirection.
--- which-key (if installed) labels the `<leader>lr` prefix via
--- `recommender.bindings.which_key`; individual key descriptions come
--- from each mapping's `desc`.

local lib = require("recommender.util.lib")

local M = {}

---Bind the global keymaps.
---@return nil
function M.bind()
  lib.map("n", "<leader>lr", "<cmd>Recommender<cr>", { desc = "Recommender" })
  lib.map("n", "<leader>lR", "<cmd>Recommender -r<cr>", { desc = "Recommender (replace mode)" })
  lib.map("n", "<leader>lrr", "<cmd>Recommender regex<cr>", { desc = "Recommender (regex)" })
  lib.map("n", "<leader>lrt", "<cmd>Recommender treesitter<cr>", { desc = "Recommender (treesitter)" })
  lib.map("n", "<leader>lrj", "<cmd>Recommender javascript<cr>", { desc = "Recommender (javascript)" })
  lib.map("n", "<leader>lrp", "<cmd>Recommender python<cr>", { desc = "Recommender (python)" })
  lib.map("n", "<leader>lrh", "<cmd>Recommender regex 5<cr>", { desc = "Recommender (high threshold)" })
  lib.map("n", "<leader>lrc", "<cmd>Recommender -c<cr>", { desc = "Recommender (project-wide, cwd)" })
end

return M

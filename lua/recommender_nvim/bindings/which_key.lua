---@module 'recommender_nvim.bindings.which_key'
---@brief Optional, guarded which-key group label for the `<leader>lr` prefix.
---@description
--- which-key is a **soft** dependency: if it is not installed this is a
--- no-op. Supports both which-key v3 (`add`) and v2 (`register`) APIs.

local M = {}

---Register the `<leader>lr` group with which-key, if available.
---@return boolean registered
function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end
  if type(wk.add) == "function" then
    wk.add({ { "<leader>lr", group = "Recommender", mode = { "n" } } })
    return true
  elseif type(wk.register) == "function" then
    wk.register({ ["<leader>lr"] = { name = "+Recommender" } }, { mode = "n" })
    return true
  end
  return false
end

---Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M

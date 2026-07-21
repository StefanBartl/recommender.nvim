---@module 'recommender.autodoc'
--- Generates helptags for recommender.nvim if missing.
--- This file is loaded exactly once at startup by Neovim.

-- Resolve plugin root directory from this file location
local source = debug.getinfo(1, "S").source
if type(source) ~= "string" then
  return
end

local file = source:sub(2)
local plugin_root = vim.fn.fnamemodify(file, ":h:h")
local doc_dir = plugin_root .. "/doc"
local tags_file = doc_dir .. "/tags"

-- Generate helptags only if necessary
if vim.fn.isdirectory(doc_dir) == 1 and vim.fn.filereadable(tags_file) == 0 then
  vim.schedule(function()
    pcall(function() vim.cmd("silent helptags " .. vim.fn.fnameescape(doc_dir)) end)
  end)
end

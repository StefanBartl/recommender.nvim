-- luacheck configuration for recommender.nvim
std = "luajit"
-- `vim` is writable (we set vim.g.*, vim.bo[buf].* etc.); `read_globals` would
-- flag those field assignments as "setting a read-only field".
globals = { "vim" }
max_line_length = 130

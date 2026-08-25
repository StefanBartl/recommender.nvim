-- luacheck configuration for recommender.nvim
std = "luajit"
-- `vim` is writable (we set vim.g.*, vim.bo[buf].* etc.); `read_globals` would
-- flag those field assignments as "setting a read-only field".
globals = { "vim" }
-- Line length is stylua's job (column_width in stylua.toml), not luacheck's.
-- The only lines luacheck flagged here were long string literals and LuaLS
-- doc comments -- exactly the two things stylua cannot break, so the second
-- limit only produced findings with no clean fix.
max_line_length = false

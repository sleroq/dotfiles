-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local Util = require("lazyvim.util")

local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

map("n", "<leader>tz", ":TZAtaraxis<CR>")
map("n", "<leader>tn", ":TZNarrow<CR>")
map("v", "<leader>tn", ":'<,'>TZNarrow<CR>")
map("n", "<leader>tf", ":TZFocus<CR>")
map("n", "<leader>tm", ":TZMinimalist<CR>")

-- remap floating terminal
map("", "<leader>ft", "<nop>")
map("", "<leader>fT", "<nop>")


map("n", "<leader>tt", function() Util.float_term(nil, { cwd = Util.get_root() }) end, { desc = "Terminal (root dir)" })
map("n", "<leader>tT", function() Util.float_term() end, { desc = "Terminal (cwd)" })

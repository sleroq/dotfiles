-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here


vim.cmd [[ colorscheme tokyonight-night ]]

-- Highlighting .conf files
vim.cmd [[ autocmd BufRead,BufNewFile *.conf setf dosini ]]
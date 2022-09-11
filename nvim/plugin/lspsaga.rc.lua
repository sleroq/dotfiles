local status, saga = pcall(require, 'lspsaga')
if (not status) then return end
local keymap = vim.keymap

saga.init_lsp_saga { server_filetype_map = { typescript = 'typescript' } }

local opts = { noremap = true, silent = true }

keymap.set('n', 'gh', '<Cmd>Lspsaga lsp_finder<CR>', opts)
-- keymap.set('n', 'gp', '<Cmd>Lspsaga peek_definition<CR>', opts) -- conflicts with something
keymap.set({ 'n', 'v' }, 'ga', '<Cmd>Lspsaga code_action<CR>', opts)
keymap.set('n', 'gr', '<Cmd>Lspsaga rename<CR>', opts)

keymap.set('n', '<C-j>', '<Cmd>Lspsaga diagnostic_jump_next<CR>', opts)
keymap.set('n', 'K', '<Cmd>Lspsaga hover_doc<CR>', opts)

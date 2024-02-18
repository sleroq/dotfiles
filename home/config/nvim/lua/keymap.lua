-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Buffer keymaps
vim.keymap.set('n', '<leader>bd', ':bd<CR>', { desc = 'Close buffer' })
vim.keymap.set('n', '<leader>bn', ':bn<CR>', { desc = 'Next buffer' })
vim.keymap.set('n', '<leader>bp', ':bp<CR>', { desc = 'Previous buffer' })

-- Window keymaps
vim.keymap.set('n', '<leader>ws', ':split<CR>', { desc = 'Split window' })
vim.keymap.set('n', '<leader>wv', ':vsplit<CR>', { desc = 'Vsplit window' })

vim.keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Move to window on the left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Move to window below' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Move to window above' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Move to window on the right' })

vim.keymap.set('n', '<leader><S-h>', '<C-w>H', { desc = 'Move window to the left' })
vim.keymap.set('n', '<leader><S-j>', '<C-w>J', { desc = 'Move window to the bottom' })
vim.keymap.set('n', '<leader><S-k>', '<C-w>K', { desc = 'Move window to the top' })
vim.keymap.set('n', '<leader><S-l>', '<C-w>L', { desc = 'Move window to the right' })

vim.keymap.set('n', '<leader>w-', '<C-w>-', { desc = 'Decrease window height' })
vim.keymap.set('n', '<leader>w+', '<C-w>+', { desc = 'Increase window height' })
vim.keymap.set('n', '<leader>w<', '<C-w><', { desc = 'Decrease window width' })
vim.keymap.set('n', '<leader>w>', '<C-w>>', { desc = 'Increase window width' })
vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = 'Balance window sizes' })
vim.keymap.set('n', '<leader>wd', '<C-w>q', { desc = 'Close window' })
vim.keymap.set('n', '<leader>qq', ':q<CR>', { desc = 'Close window' })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

-- Neotree keymaps
vim.keymap.set('n', '<leader>op', ':Neotree toggle<CR>', { desc = 'Toggle file tree' })

-- Git keymaps
vim.keymap.set('n', '<leader>gg', ':G<CR><C-w><S-l>', { desc = 'Git status' })

local status, zenmode = pcall(require, 'zen-mode')
if (not status) then return end

zenmode.setup()

vim.keymap.set('n', '<C-w>o', '<cmd>ZenMode<cr>', { silent = true })

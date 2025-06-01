local neogit = require('neogit')

function openGit()
  neogit.open({ kind = "vsplit" })
end
-- Git keymaps
vim.keymap.set('n', '<leader>gg', openGit, { desc = 'Git status' })

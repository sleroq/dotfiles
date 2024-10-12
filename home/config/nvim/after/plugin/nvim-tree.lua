require('nvim-tree').setup {
  git = {
    ignore = false,
  },
}

local nvimTreeFocusOrToggle = function()
  local nvimTree = require 'nvim-tree.api'
  local currentBuf = vim.api.nvim_get_current_buf()
  local currentBufFt = vim.api.nvim_get_option_value('filetype', { buf = currentBuf })
  if currentBufFt == 'NvimTree' then
    nvimTree.tree.toggle()
  else
    nvimTree.tree.focus()
  end
end

vim.keymap.set('n', '<leader>ff', nvimTreeFocusOrToggle, { desc = '[F]ile browser' })
vim.keymap.set('n', '<leader>op', nvimTreeFocusOrToggle, { desc = '[F]ile browser' })

vim.keymap.set('n', '<leader>bt', ':NvimTreeFindFile<CR>', { desc = 'Current [B]uffer in [T]ree' })

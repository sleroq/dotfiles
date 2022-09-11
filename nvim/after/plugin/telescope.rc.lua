local status, telescope = pcall(require, 'telescope')
if (not status) then return end

local actions = require('telescope.actions')
local builtin = require('telescope.builtin')
local fb_actions = telescope.extensions.file_browser.actions

local function telescope_buffer_dir() return vim.fn.expand('%:p:h') end

telescope.setup({
  defaults = { mappings = { n = { ['q'] = actions.close } } },
  extensions = {
    file_browser = {
      theme = 'dropdown',
      -- disables netrw and use telescope-file-browser in its place
      hijack_netrw = true,
      mappings = {
        -- your custom insert mode mappings
        ['i'] = { ['<C-w>'] = function() vim.cmd('normal vbd') end },
        ['n'] = {
          -- your custom normal mode mappings
          ['h'] = fb_actions.goto_parent_dir,
          ['/'] = function() vim.cmd('startinsert') end
        }
      }
    }
  }
})

telescope.load_extension('file_browser')

vim.keymap.set('n', '<C-Space>', function() builtin.live_grep() end)
vim.keymap.set('n', '\\\\', function() builtin.buffers() end)
vim.keymap.set('n', '<Leader>t', function() builtin.help_tags() end)
vim.keymap.set('n', '<Leader><Leader>', function() builtin.resume() end)
vim.keymap.set('n', '<Leader>e', function() builtin.diagnostics() end)
vim.keymap.set('n', '<Leader>f', function()
  builtin.find_files({ no_ignore = false, hidden = true })
end)

function _G.file_browser ()
  telescope.extensions.file_browser.file_browser({
    respect_gitignore = false,
    hidden = true,
    grouped = true,
  })
end

vim.keymap.set('n', 'te', ':tabnew<Return>:lua file_browser()<Return>')
vim.keymap.set('n', 'se', file_browser)
-- vim.keymap.set('n', 'se', ':Telescope file_browser<Return>')

vim.keymap.set('n', 'sf', function()
  telescope.extensions.file_browser.file_browser({
    path = '%:p:h',
    cwd = telescope_buffer_dir(),
    respect_gitignore = false,
    hidden = true,
    grouped = true,
    previewer = false,
    initial_mode = 'normal',
    layout_config = { height = 40 }
  })
end)

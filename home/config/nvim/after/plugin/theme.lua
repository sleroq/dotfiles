require('catppuccin').setup {
    transparent_background = true,
    integrations = {
        cmp = true,
        gitsigns = true,
        treesitter = true,
        telescope = true,
    },
}

vim.cmd.colorscheme 'catppuccin-macchiato'

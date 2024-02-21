local macchiato = require('catppuccin.palettes').get_palette 'macchiato'

require('nvim-web-devicons').setup {
    override_by_filename = {
        ['license'] = {
            icon = '󰿃',
            color = macchiato.yellow,
            name = 'License'
        },
        ['.gitignore'] = {
            icon = "",
            color = macchiato.red,
            name = "Gitignore"
        },
    },
    override_by_extension = {
        ["el"] = {
            icon = '',
            color = macchiato.blue,
            name = 'EmacsLisp'
        },
        ["go"] = {
            icon = '',
            color = macchiato.blue,
            name = 'Golang'
        },
        ["bash*"] = {
            icon = "",
            color = macchiato.green,
            name = "Bash",
        },
    },
}

-- Set <space> as the leader key
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- [[ :help lazy.nvim.txt ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system {
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable',
        lazypath,
    }
end
vim.opt.rtp:prepend(lazypath)

-- [[ Configure plugins ]]
require('lazy').setup({
    'nvim-tree/nvim-web-devicons',

    -- Git related plugins
    'tpope/vim-fugitive',

    -- Detect tabstop and shiftwidth automatically
    -- 'tpope/vim-sleuth',

    -- LSP related plugins
    'neovim/nvim-lspconfig',
    'hrsh7th/cmp-buffer',
    opts = {},
    'hrsh7th/cmp-path',
    'saadparwaiz1/cmp_luasnip',
    'hrsh7th/cmp-nvim-lua',
    'rafamadriz/friendly-snippets',
    { 'L3MON4D3/LuaSnip',                  opts = {} },
    { 'williamboman/mason.nvim',           opts = {} },
    { 'williamboman/mason-lspconfig.nvim', opts = {} },
    { 'hrsh7th/nvim-cmp',                  opts = {} },
    { 'hrsh7th/cmp-nvim-lsp',              opts = {} },
    { 'VonHeikemen/lsp-zero.nvim',         branch = 'v3.x', lazy = true, config = false },

    {
        'nvimdev/guard.nvim',
        -- Builtin configuration, optional
        dependencies = {
            'nvimdev/guard-collection',
        },
    },

    { 'j-hui/fidget.nvim',    opts = {} },
    { 'folke/neodev.nvim',    opts = {} },
    { 'folke/which-key.nvim', opts = {} },
    'lewis6991/gitsigns.nvim',

    {
        'catppuccin/nvim',
        name = 'catppuccin',
        priority = 1000,
        lazy = false,
        config = function()
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
        end,
    },

    {
        -- Set lualine as statusline
        'nvim-lualine/lualine.nvim',
        -- See `:help lualine.txt`
        opts = {
            options = {
                icons_enabled = false,
                theme = 'palenight',
            },
        },
    },

    {
        -- Add indentation guides even on blank lines
        'lukas-reineke/indent-blankline.nvim',
        -- Enable `lukas-reineke/indent-blankline.nvim`
        -- See `:help ibl`
        main = 'ibl',
        opts = {},
    },

    -- 'gc' to comment visual regions/lines
    { 'numToStr/Comment.nvim',  opts = {} },

    -- Fuzzy Finder (files, lsp, etc)
    {
        'nvim-telescope/telescope.nvim',
        branch = '0.1.x',
        dependencies = {
            'nvim-lua/plenary.nvim',
            -- Fuzzy Finder Algorithm which requires local dependencies to be built.
            -- Only load if `make` is available. Make sure you have the system
            -- requirements installed.
            {
                'nvim-telescope/telescope-fzf-native.nvim',
                -- NOTE: If you are having trouble with this installation,
                --       refer to the README for telescope-fzf-native for more instructions.
                build = 'make',
                cond = function()
                    return vim.fn.executable 'make' == 1
                end,
            },
        },
    },

    {
        -- Highlight, edit, and navigate code
        'nvim-treesitter/nvim-treesitter',
        dependencies = {
            'nvim-treesitter/nvim-treesitter-textobjects',
        },
        build = ':TSUpdate',
    },
    {
        'zbirenbaum/copilot.lua',
        config = function()
            require('copilot').setup {
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    debounce = 75,
                    keymap = {
                        accept = '<M-l>',
                        accept_word = false,
                        accept_line = false,
                        next = '<M-]>',
                        prev = '<M-[>',
                        dismiss = '<C-]>',
                    },
                },
            }
        end,
    },
    'zbirenbaum/copilot-cmp',

    {
        'amitds1997/remote-nvim.nvim',
        version = '*',                       -- Pin to GitHub releases
        dependencies = {
            'nvim-lua/plenary.nvim',         -- For standard functions
            'MunifTanjim/nui.nvim',          -- To build the plugin UI
            'nvim-telescope/telescope.nvim', -- For picking b/w different remote methods
        },
        config = true,
    },

    'folke/zen-mode.nvim',
    { 'echasnovski/mini.pairs', version = false, opts = {} },

    {
        'kevinhwang91/nvim-ufo',
        setup = function()
            -- Using ufo provider need remap `zR` and `zM`.
            vim.keymap.set('n', 'zR', require('ufo').openAllFolds)
            vim.keymap.set('n', 'zM', require('ufo').closeAllFolds)
        end,
    },

    {
        'nvim-tree/nvim-tree.lua',
        version = '*',
        lazy = false,
        dependencies = {
            'nvim-tree/nvim-web-devicons',
        },
        config = function()
            require('nvim-tree').setup {}
        end,
    },
    'ledger/vim-ledger',
    'nathangrigg/vim-beancount',
    'benfowler/telescope-luasnip.nvim',
    'nvim-telescope/telescope-frecency.nvim',
    {
        'LhKipp/nvim-nu',
        config = function()
            require('nvim-tree').setup {}
        end,
    },
    {
        'folke/todo-comments.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
        opts = {},
    },
    {
        'theRealCarneiro/hyprland-vim-syntax',
        dependencies = { 'nvim-treesitter/nvim-treesitter' },
        ft = 'hypr'
    },
}, {})

-- [[ Setting options ]]
require 'sleroq'

-- Set <space> as the leader key
-- Must happen before plugins are required
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.cmd 'set shell=/bin/sh'

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
  -- Git related plugins
  'tpope/vim-fugitive',
  'lewis6991/gitsigns.nvim',

  { 'VonHeikemen/lsp-zero.nvim', branch = 'v4.x' },
  'neovim/nvim-lspconfig',

  'hrsh7th/cmp-nvim-lsp',
  'hrsh7th/nvim-cmp',
  'hrsh7th/cmp-buffer',
  'hrsh7th/cmp-path',

  'onsails/lspkind.nvim',

  'L3MON4D3/LuaSnip',
  'saadparwaiz1/cmp_luasnip',
  'benfowler/telescope-luasnip.nvim',

  { 'j-hui/fidget.nvim',         opts = {} },
  { 'folke/which-key.nvim',      opts = {} },

  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    lazy = false,
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
    'amitds1997/remote-nvim.nvim',
    version = '*',                     -- Pin to GitHub releases
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
    dependencies = {
      'kevinhwang91/promise-async',
    },
  },

  {
    'nvim-tree/nvim-tree.lua',
    version = '*',
    lazy = false,
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
  },

  'ledger/vim-ledger',
  'nathangrigg/vim-beancount',

  'nvim-telescope/telescope-frecency.nvim',
  'LhKipp/nvim-nu',
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
  },
  {
    'theRealCarneiro/hyprland-vim-syntax',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    ft = 'hypr',
  },
  {

    'nmac427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup {}
    end,
  },
  {
    'wakatime/vim-wakatime',
    init = function()
      vim.g.wakatime_CLIPath = '~/.nix-profile/bin/wakatime-cli'
    end,
    lazy = false,
  },

  {
    "supermaven-inc/supermaven-nvim",
    config = function()
      require("supermaven-nvim").setup({})
    end,
  },

  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim", -- required by telescope
        "MunifTanjim/nui.nvim",

        -- optional
        "rcarriga/nvim-notify",
    },
    opts = {
      arg = "leetcode.nvim",
      lang = "golang",
      image_support = false,
    },
  },
}, {})

-- [[ Setting options ]]
require 'sleroq'

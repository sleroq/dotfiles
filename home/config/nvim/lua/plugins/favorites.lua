
-- please e that this is the only way to get the cmp plugin working with
return {
  -- -- add gruvbox
  -- { "ellisonleao/gruvbox.nvim" },
  -- 
  -- -- Configure LazyVim to load gruvbox
  -- {
  --   "LazyVim/LazyVim",
  --   opts = {
  --     colorscheme = "gruvbox",
  --   },
  -- },

  -- change trouble config
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
    opts = { use_diagnostic_signs = true },
  },

  { "LnL7/vim-nix" },

  {
    "Pocco81/true-zen.nvim", 
    opts = {
      modes = {
        ataraxis = {
          minimum_writing_area = {
            width = 100,
            height = 44,
          },
        },
      },
    },
  },

  {
    "MunifTanjim/eslint.nvim",
    opts = {
      bin = 'eslint_d',
      code_actions = {
        enable = true,
        apply_on_save = {
          enable = true,
          types = { "directive", "problem", "suggestion", "layout" },
        },
        disable_rule_comment = {
          enable = true,
          location = "separate_line", -- or `same_line`
        },
      },
      diagnostics = {
        enable = true,
        report_unused_disable_directives = false,
        run_on = "type", -- or `save`
      },
    },
  },

  { "tpope/vim-fugitive" },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   dependencies = { "jcdickinson/codeium.nvim" },
  --   ---@param opts cmp.ConfigSchema
  --   opts = function(_, opts)
  --     local cmp = require("cmp")
  --     opts.sources = cmp.config.sources(vim.list_extend(opts.sources, { { name = "codeium" } }))
  --   end,
  -- }
 -- {
 --   "neovim/nvim-lspconfig",
 --   dependencies = { "jose-elias-alvarez/typescript.nvim" },
 --   config = function()
 --     require'lspconfig'.denols.setup{}
 --   end,
 -- },
}

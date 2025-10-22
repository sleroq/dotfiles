vim.opt.winborder = "rounded"
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.showtabline = 0
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.o.smartcase = true
vim.opt.smartindent = true
vim.opt.undofile = true
vim.opt.number = true
-- vim.opt.relativenumber = true
vim.o.breakindent = true
vim.o.timeoutlen = 200
vim.o.completeopt = "menuone,noselect"
vim.o.termguicolors = true
vim.o.mouse = ""
vim.o.updatetime = 2000
vim.o.swapfile = false
vim.opt.splitright = true
vim.opt.expandtab = true -- fuck the tabs
vim.cmd.packadd("nohlsearch")

-- experimental stuff
vim.o.path = "**"         -- for the find command, maybe helps with completion as well
vim.opt.lazyredraw = true -- presumably better for ssh

vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",        version = "main" },
    { src = "https://github.com/nvim-telescope/telescope.nvim",          version = "master" },

    { src = "https://github.com/NeogitOrg/neogit" },
    -- neogit deps:
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/sindrets/diffview.nvim" },

    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    { src = "https://github.com/vague2k/vague.nvim" },
    { src = "https://github.com/chentoast/marks.nvim" },
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" }, -- TODO: use atleast once?
    { src = "https://github.com/nvim-telescope/telescope-frecency.nvim" },

    { src = "https://github.com/folke/which-key.nvim" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    -- { src = "https://github.com/folke/todo-comments.nvim" }, -- FIXME: does not work

    { src = "https://github.com/j-hui/fidget.nvim" },

    -- { src = "https://github.com/neoclide/coc.nvim", version = "release" },
    { src = "https://github.com/prisma/vim-prisma" },
    { src = "https://github.com/AckslD/nvim-neoclip.lua" },

    -- TODO: enable when I start accounting again
    -- { src = "ledger/vim-ledger" },
    -- { src = "nathangrigg/vim-beancount" },

    -- TODO: Completion?
    -- { src = "hrsh7th/cmp-nvim-lsp" },
    -- { src = "hrsh7th/nvim-cmp" },
    -- { src = "hrsh7th/cmp-buffer" },
    -- { src = "hrsh7th/cmp-path" },
    -- { src = "onsails/lspkind.nvim" },
    { src = "https://github.com/supermaven-inc/supermaven-nvim" },
    { src = "https://github.com/NickvanDyke/opencode.nvim" },
    { src = "https://github.com/folke/snacks.nvim" }, -- dep for opencode

    { src = "https://github.com/mbbill/undotree" },
    { src = "https://github.com/NMAC427/guess-indent.nvim" },
    -- { src = "https://github.com/folke/trouble.nvim" }, -- TODO: seems usefull
    -- { src = "https://github.com/sigmaSd/deno-nvim" }, -- TODO: enable when I hit some limitation of the default config

    -- https://github.com/coffebar/neovim-project -- maybe this
})

require "guess-indent".setup({})

-- require "vague".setup({ transparent = true })
require "vague".setup()
vim.cmd("colorscheme vague")
vim.cmd(":hi statusline guibg=NONE")

require "lualine".setup({}) -- FIXME: is it for weak?

require "marks".setup {
    builtin_marks = { "<", ">", "^" },
    refresh_interval = 250,
    sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
    excluded_filetypes = {},
    excluded_buftypes = {},
    mappings = {}
}

require("supermaven-nvim").setup({ keymaps = { accept_suggestion = "<C-l>" } })

require("neoclip").setup({ preview = true, })

local telescope = require("telescope")
telescope.setup({
    defaults = {
        color_devicons = true,
        sorting_strategy = "ascending",
        borderchars = { "", "", "", "", "", "", "", "" },
        path_displays = "smart",
        layout_strategy = "horizontal",
        layout_config = {
            height = 100,
            width = 400,
            prompt_position = "top",
            preview_cutoff = 40,
        }
    }
})
telescope.load_extension("frecency")
telescope.load_extension("ui-select")

vim.lsp.config["lua_ls"] = {
    settings = {
        Lua = {
            workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
            },
            diagnostics = {
                globals = {
                    "vim"
                }
            },
        }
    }
}

vim.lsp.enable({ "lua_ls", "nixd", "gopls", "ts_ls" })

require("oil").setup({
    lsp_file_methods = {
        enabled = true,
        timeout_ms = 1000,
        autosave_changes = true,
    },
    columns = {
        "permissions",
        "icon",
    },
    float = {
        max_width = 0.7,
        max_height = 0.6,
        border = "rounded",
    },
})

local tsbuiltin = require("telescope.builtin")
local map = vim.keymap.set

local function find_noignore()
    tsbuiltin.find_files({
        find_command = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--files",
            "--hidden",
            "--no-ignore"
        }
    })
end

vim.g.mapleader = " "
map({ "v", "x" }, "<C-y>", '"+y', { desc = "System clipboard yank" })
map({ "n" }, "<C-x>", "<Cmd>:Telescope neoclip<CR>", { desc = "Clipboard manager" }) -- maybe use registers like a chad instead of this?
map({ "n" }, "<leader>/", tsbuiltin.live_grep, { desc = "Live grep" })
map({ "n" }, "<leader><leader>", "<Cmd>:Telescope frecency workspace=CWD<CR>", { desc = "Find files" })
map({ "n" }, "<leader>ff", tsbuiltin.find_files, { desc = "Find files" })
map({ "n" }, "<leader>fF", find_noignore, { desc = "Find files no .gitignore" })
map({ "n" }, "<leader>b", tsbuiltin.buffers, { desc = "Find buffers" }) -- is :b tab not enough?
map({ "n" }, "<leader>n", "<Cmd>:bn<CR>", { desc = "Next buffer" })
map({ "n" }, "<leader>p", "<Cmd>:bp<CR>", { desc = "Prev buffers" })
map({ "n" }, "<leader>gr", tsbuiltin.lsp_references, { desc = "Telescope tags" })
map({ "n" }, "<leader>r", tsbuiltin.resume, { desc = "Telescope resume last pick" })
map({ "n" }, "<leader>x", "<Cmd>:bd<CR>", { desc = "Quit the current buffer." })
map({ "n" }, "<leader>X", "<Cmd>:bd!<CR>", { desc = "Force quit the current buffer." })
map({ "n" }, "<leader>gg", "<Cmd>:Neogit<CR>", { desc = "Open git shit" })
map({ "n" }, "gd", vim.lsp.buf.definition, { desc = "Jump to definition" })
map({ "n" }, "<leader>t", "<Cmd>:vs | te<CR>", { desc = "Open terminal" })
map({ "n", "v", "x" }, "<leader>gf", vim.lsp.buf.format, { desc = "Format current buffer" })
map({ "n" }, "<leader>e", "<cmd>Oil<CR>", { desc = "Open oil" })

if vim.g.neovide then
    map("n", "<sc-v>", 'l"+P', { noremap = true })
    map("v", "<sc-v>", '"+P', { noremap = true })
    map("i", "<sc-v>", '<ESC>"+p', { noremap = true })
    map("n", "<sc-v>", '"+p', { noremap = true })
    map("t", "<sc-v>", '<C-\\><C-n>"+Pi', { noremap = true })
    vim.o.guifont = "JetBrainsMono Nerd Font:h14"
end

local opencode = require("opencode")
map({ "n", "x" }, "<leader>oa", function() opencode.ask("@this: ", { submit = true }) end,
    { desc = "Ask about this" })
map({ "n", "x" }, "<leader>os", function() opencode.select() end, { desc = "Select prompt" })
map({ "n", "x" }, "<leader>o+", function() opencode.prompt("@this") end, { desc = "Add this" })
map("n", "<leader>ot", function() opencode.toggle() end, { desc = "Toggle embedded" })
map("n", "<leader>oc", function() opencode.command() end, { desc = "Select command" })
map("n", "<leader>on", function() opencode.command("session_new") end, { desc = "New session" })
map("n", "<leader>oi", function() opencode.command("session_interrupt") end, { desc = "Interrupt session" })
map("n", "<leader>oA", function() opencode.command("agent_cycle") end, { desc = "Cycle selected agent" })
map("n", "<S-C-u>", function() opencode.command("messages_half_page_up") end,
    { desc = "Messages half page up" })
map("n", "<S-C-d>", function() opencode.command("messages_half_page_down") end,
    { desc = "Messages half page down" })

-- disable ts_ls for deno project
vim.api.nvim_create_autocmd("User", {
    pattern = "LspAttach",
    callback = function()
        local cwd = vim.fn.getcwd()
        if cwd:match("slusha") then
            vim.cmd("LspStop ts_ls")
            vim.cmd("LspStart denols")
        end
    end,
})

local ts_parsers = {
    "go", "gomod", "gosum", "vim", "vimdoc", "javascript",
    "zig", "typescript", "json", "dockerfile", "sql",
    "yaml", "bash", "gitignore", "prisma",
}
local nts = require("nvim-treesitter")
nts.install(ts_parsers)

vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        local filetype = args.match
        local lang = vim.treesitter.language.get_lang(filetype)
        if lang and vim.treesitter.language.add(lang) then
            vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"               -- folds, provided by Neovim
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation, provided by nvim-treesitter
            vim.treesitter.start()                                            -- syntax highlighting, provided by Neovim
        end
    end,
})

vim.api.nvim_create_autocmd("PackChanged", { callback = function() nts.update() end })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*sh.example",
    callback = function()
        vim.bo.filetype = "sh"
    end,
})

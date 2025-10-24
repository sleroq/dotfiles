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
vim.opt.expandtab = true
vim.cmd.packadd("nohlsearch")
vim.cmd.packadd("cfilter")
vim.o.grepprg = "rg --vimgrep --hidden --glob '!.git/*' --glob '!node_modules/*'"
vim.opt.shell = "bash"

-- experimental stuff
vim.o.path = "**"         -- for the find command, maybe helps with completion as well
vim.opt.lazyredraw = true -- presumably better for ssh

vim.pack.add({
    -- To make sure neovim is not too fast:
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",        version = "main" },
    -- 16k+ loc of lua bloat to show results of fuzzy search:
    { src = "https://github.com/nvim-telescope/telescope.nvim",          version = "master" },

    -- To avoid learning git cli:
    { src = "https://github.com/NeogitOrg/neogit" },
    -- deps for neogit:
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/sindrets/diffview.nvim" },

    -- Highlights what lines have been changed (can't remember myself):
    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    -- workaround for skill issue using marks. this really helps for small brain:
    { src = "https://github.com/chentoast/marks.nvim" },

    -- bloated file manager to avoid learning cd and ls:
    { src = "https://github.com/stevearc/oil.nvim" },

    -- can't code if I don't see pretty icon on my screen:
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },

    -- maybe actually useful stuff:
    { src = "https://github.com/neovim/nvim-lspconfig" },

    -- more bloat:
    { src = "https://github.com/nvim-telescope/telescope-ui-select.nvim" }, -- TODO: use atleast once?
    -- another workaround for skill issue using marks
    { src = "https://github.com/nvim-telescope/telescope-frecency.nvim" },

    -- workaround for bad memory of keymaps (and helps with usage of registers)
    { src = "https://github.com/folke/which-key.nvim" },
    -- TODO: not even sure why I need this -- TODO: not even sure why I need this.
    -- it's so useless there is nothing to replace it with
    -- { src = "https://github.com/j-hui/fidget.nvim" }, -- pretty LSP status

    -- { src = "https://github.com/neoclide/coc.nvim", version = "release" }, -- vsc*de addons to use prisma LSP server or other proprietary stuff
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
    -- to avoid learning to type fast and setting up proper completion
    { src = "https://github.com/supermaven-inc/supermaven-nvim" },
    -- workaround for stupidity (asking agent about the code)
    { src = "https://github.com/NickvanDyke/opencode.nvim" },
    -- another bloat dependency because opencode can't use telescope
    { src = "https://github.com/folke/snacks.nvim" },

    { src = "https://github.com/mbbill/undotree" },
    -- not even sure if this is a skill issue or what,
    -- but I have different indentation in different projects
    { src = "https://github.com/NMAC427/guess-indent.nvim" },
    -- { src = "https://github.com/folke/trouble.nvim" }, -- TODO: seems useful
    -- { src = "https://github.com/sigmaSd/deno-nvim" }, -- TODO: enable when I hit some limitation of the default config

    -- https://github.com/coffebar/neovim-project -- maybe this
    { src = "https://github.com/folke/zen-mode.nvim" },

    -- Maybe this is useful for work
    { src = "https://github.com/harrisoncramer/gitlab.nvim" },
    { src = "https://github.com/MunifTanjim/nui.nvim" }, -- Dep for gitlab.nvim

    -- Workaround for bloated config - so stuff gets disabled on large files
    { src = "https://github.com/pteroctopus/faster.nvim" },

    { src = "https://github.com/kdheepak/monochrome.nvim" },
    { src = "https://github.com/vague2k/vague.nvim" },
})

require("faster").setup()
require "guess-indent".setup({})

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

require("neogit").setup({
    kind = "replace",
})

require("diffview")
local gitlab = require("gitlab")
gitlab.setup({
    connection_settings = {
        insecure = true,
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
map({ "n" }, "<leader>gm", gitlab.choose_merge_request, { desc = "Open git shit" })
map({ "n" }, "gd", vim.lsp.buf.definition, { desc = "Jump to definition" })

map({ "n", "v", "x" }, "<leader>gf", vim.lsp.buf.format, { desc = "Format current buffer" })
map({ "n" }, "<leader>e", "<cmd>Oil<CR>", { desc = "Open oil" })

vim.api.nvim_create_user_command("TermNu", function() vim.cmd("terminal nu") end, {})
map({ "n" }, "<leader>t", "<Cmd>:vs | TermNu<CR>", { desc = "Open terminal" })

if vim.g.neovide then -- Copy paste for neovide
    map("n", "<sc-v>", 'l"+P')
    map("v", "<sc-v>", '"+P')
    map("i", "<sc-v>", '<ESC>"+p')
    map("n", "<sc-v>", '"+p')
    map("t", "<sc-v>", '<C-\\><C-n>"+Pi')
    vim.o.guifont = "JetBrainsMono Nerd Font:h14"
    vim.g.neovide_cursor_vfx_mode = "pixiedust"
    vim.g.neovide_opacity = 0.8
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

local zen = require("zen-mode")
zen.setup({
    plugins = {
        kitty = {
            enabled = true,
        },
        neovide = {
            enabled = true,
            disable_animations = {
                neovide_opacity = 1,
                neovide_cursor_animate_command_line = true,
                neovide_scroll_animation_length = 0.3,
                neovide_position_animation_length = 0.15,
                neovide_cursor_animation_length = 0.15,
                neovide_cursor_vfx_mode = "pixiedust",
            },
        },
    },
})
local toggle_zen = function()
    zen.toggle({
        window = {
            backdrop = 0,
        },
    })
end
map({ "n" }, "<leader>z", toggle_zen, { desc = "Toggle zen mode" })

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

-- require "vague".setup()
vim.cmd("colorscheme monochrome")

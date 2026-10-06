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
vim.o.linebreak = true
vim.o.timeoutlen = 200
vim.o.completeopt = "menuone,noselect"
vim.o.termguicolors = true
vim.o.mouse = ""
vim.o.updatetime = 2000
vim.o.swapfile = false
vim.opt.splitright = true
vim.opt.expandtab = true
vim.opt.foldmethod = "manual" -- UFO supplies automatic folds while allowing manual zf folds.
vim.opt.foldlevel = 99 -- Keep folds open until explicitly closed.
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true
vim.cmd.packadd("nohlsearch")
vim.cmd.packadd("cfilter")
vim.o.grepprg = "rg --vimgrep --hidden --glob '!.git/*' --glob '!node_modules/*'"
vim.opt.shell = "bash"
vim.opt.conceallevel = 2 -- for markdown shit

-- experimental stuff
vim.o.path = "**"         -- for the find command, maybe helps with completion as well
vim.opt.lazyredraw = true -- presumably better for ssh

vim.opt.runtimepath:prepend(vim.env.FFF_NVIM)

vim.pack.add({
    -- To make sure neovim is not too fast:
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",        version = "main" },
    { src = "https://github.com/kevinhwang91/promise-async" },
    { src = "https://github.com/kevinhwang91/nvim-ufo" },

    -- To avoid learning git cli:
    { src = "https://github.com/NeogitOrg/neogit" },
    -- deps for neogit:
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/esmuellert/codediff.nvim" },

    -- Highlights what lines have been changed (can't remember myself):
    { src = "https://github.com/lewis6991/gitsigns.nvim" },

    -- workaround for skill issue using marks. this really helps for small brain:
    { src = "https://github.com/chentoast/marks.nvim" },

    -- Jump anywhere visible with a couple of keystrokes:
    { src = "https://github.com/folke/flash.nvim" },

    -- bloated file manager to avoid learning cd and ls:
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/Eutrius/Otree.nvim" },

    -- can't code if I don't see pretty icon on my screen:
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },

    -- maybe actually useful stuff:
    { src = "https://github.com/neovim/nvim-lspconfig" },

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
    -- Native Pi sessions, workspaces, and reviewed edits:
    { src = "https://github.com/OXY2DEV/markview.nvim" },
    { src = "https://github.com/saya-ashen/agent-workbench.nvim" },
    -- Picker and input UI:
    { src = "https://github.com/folke/snacks.nvim" },

    { src = "https://github.com/mbbill/undotree" },
    -- not even sure if this is a skill issue or what,
    -- but I have different indentation in different projects
    { src = "https://github.com/NMAC427/guess-indent.nvim" },
    -- { src = "https://github.com/folke/trouble.nvim" }, -- TODO: seems useful
    -- { src = "https://github.com/sigmaSd/deno-nvim" }, -- TODO: enable when I hit some limitation of the default config

    -- https://github.com/coffebar/neovim-project -- maybe this
    { src = "https://github.com/folke/zen-mode.nvim" },

    -- Workaround for bloated config - so stuff gets disabled on large files
    { src = "https://github.com/pteroctopus/faster.nvim" },

    { src = "https://github.com/kdheepak/monochrome.nvim" },
    { src = "https://github.com/vague2k/vague.nvim" },
    { src = "https://github.com/rose-pine/neovim" },

    { src = "https://github.com/obsidian-nvim/obsidian.nvim" },
    { src = "https://github.com/sotte/presenting.nvim" },
    { src = "https://github.com/3rd/image.nvim" },
    { src = "https://github.com/3rd/diagram.nvim" },
})

vim.g.fff = {
    lazy_sync = true,
    layout = {
        width = 1,
        height = 1,
        prompt_position = "top",
        preview_position = "right",
        preview_size = 0.5,
        flex = false, -- Keep the preview beside the files, even in narrow windows.
        -- FFF reserves border cells even with "none"; spaces keep those cells opaque.
        border = {
            { " ", " ", " ", " ", " ", " ", " ", " " },
            { " ", " ", " ", " ", " " },
        },
    },
    hl = {
        border = "NormalFloat",
    },
}

-- presenting.nvim uses an unnamed scratch buffer, so resolve slide images against the source file.
local presentation_source
local presenting = require("presenting")
local start_presentation = presenting.start
presenting.start = function(...)
    presentation_source = vim.api.nvim_buf_get_name(0)
    return start_presentation(...)
end

-- Terminal image rendering is unavailable in Neovide and headless/embedded sessions.
if not vim.g.neovide and vim.uv.guess_handle(1) == "tty" then
    require("image").setup({
        backend = "kitty",
        processor = "magick_cli",
        integrations = {
            markdown = {
                enabled = true,
                floating_windows = true,
                resolve_image_path = function(document_path, image_path, fallback)
                    if document_path == "" and presentation_source then
                        document_path = presentation_source
                    end
                    return fallback(document_path, image_path)
                end,
            },
        },
    })
    -- Render fenced Mermaid blocks inline; requires mermaid-cli's mmdc on PATH.
    require("diagram").setup({
        integrations = { require("diagram.integrations.markdown") },
        renderer_options = {
            mermaid = { theme = "dark", background = "transparent" },
        },
    })
end

presenting.setup({
    options = { width = vim.o.columns },
})

local ufo = require("ufo")
ufo.setup({
    provider_selector = function()
        return { "treesitter", "indent" }
    end,
})
vim.keymap.set("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
vim.keymap.set("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds, { desc = "Open folds except configured kinds" })
vim.keymap.set("n", "zm", ufo.closeFoldsWith, { desc = "Close another fold level" })

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

require("flash").setup({})

require("supermaven-nvim").setup({ keymaps = { accept_suggestion = "<C-l>" } })

require("agent-workbench").setup({
    -- Apply each workspace's direnv environment only to its Pi process.
    cli = { bin = "direnv", args = { "exec", ".", "pi" } },
    layout = { default = "side", side = { position = "right", width = 80 } },
    workspace_bar = { show = "always" },
})

require("neoclip").setup({ preview = true, })

local function find_noignore()
    Snacks.picker.files({
        hidden = true,
        ignored = true,
        exclude = { "**/.git/**" },
        matcher = { frecency = true },
        title = "Find files (including ignored)",
    })
end

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

vim.lsp.config["ast_grep"] = {
    cmd = { "ast-grep", "lsp", "--config", vim.fn.expand("~/sgconfig.yml") },
    filetypes = vim.list_extend(vim.lsp.config.ast_grep.filetypes, { "svelte" }),
}

vim.lsp.enable({ "ast_grep", "lua_ls", "nixd", "gopls", "ts_ls", "svelte" })

require("oil").setup({
    default_file_explorer = false,
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

-- Otree has no icon-provider option; reuse Oil's provider for every scanned entry.
local otree_fs = require("Otree.fs")
local scan_otree_dir = otree_fs.scan_dir
local oil_icon = require("oil.util").get_icon_provider()
otree_fs.scan_dir = function(...)
    local nodes = scan_otree_dir(...)
    for _, node in ipairs(nodes) do
        node.icon, node.icon_hl = oil_icon(node.type, node.link_path or node.filename)
    end
    return nodes
end

require("Otree").setup({
    open_on_left = false,
    win_size = 35,
    hijack_netrw = true,
    oil = "float",
    keymaps = {
        ["gh"] = "actions.goto_home_dir",
        ["g."] = "actions.toggle_hidden",
    },
})

require("neogit").setup({
    kind = "replace",
    diff_viewer = "codediff",
})

require("codediff").setup({
    explorer = { width = 25 },
})

local fff = require("fff")
local map = vim.keymap.set
local unmap = vim.keymap.del

vim.g.mapleader = " "
map("n", "<leader>pp", "<Cmd>AgentWorkbench<CR>", { desc = "Toggle Pi workbench" })
map({ "n", "v" }, "<leader>pm", "<Cmd>AgentWorkbenchSendMention<CR>", { desc = "Pi mention file/selection" })
map("n", "<leader>pn", "<Cmd>AgentWorkbenchNewSession<CR>", { desc = "New Pi session" })
map("n", "<leader>pr", "<Cmd>AgentWorkbenchResume<CR>", { desc = "Resume Pi session" })
map("n", "<leader>ps", "<Cmd>AgentWorkbenchSessions<CR>", { desc = "Pi live sessions" })
map("n", "<leader>pw", "<Cmd>AgentWorkbenchWorkspaceSidebar<CR>", { desc = "Pi workspaces" })
map("n", "<leader>pd", "<Cmd>AgentWorkbenchDiff<CR>", { desc = "Review Pi changes" })
map("n", "<leader>pa", "<Cmd>AgentWorkbenchAttention<CR>", { desc = "Pi pending requests" })
map({ "v", "x" }, "<C-y>", '"+y', { desc = "System clipboard yank" })
map({ "n" }, "<C-x>", function() Snacks.picker.pick("neoclip") end, { desc = "Clipboard history" })
map({ "n" }, "<leader>/", fff.live_grep, { desc = "Live grep" })
map({ "n" }, "<leader><leader>", fff.find_files, { desc = "Find files" })
map({ "n" }, "<leader>ff", find_noignore, { desc = "Find files no .gitignore" })
map("n", "<leader>fp", function() Snacks.picker.zoxide() end, { desc = "Switch project (zoxide)" })
map({ "n" }, "<leader>b", function() Snacks.picker.buffers() end, { desc = "Find buffers" }) -- is :b tab not enough?
map({ "n" }, "<leader>n", "<Cmd>:bn<CR>", { desc = "Next buffer" })
map({ "n" }, "<leader>p", "<Cmd>:bp<CR>", { desc = "Prev buffers" })
map({ "n" }, "<leader>gr", function() Snacks.picker.lsp_references() end, { desc = "LSP references" })
map({ "n" }, "<leader>r", function() Snacks.picker.resume() end, { desc = "Resume last picker" })
map("n", "<leader>fl", function() Snacks.picker.pickers() end, { desc = "List Snacks pickers" })
map({ "n" }, "<leader>x", "<Cmd>:bd<CR>", { desc = "Quit the current buffer." })
map({ "n" }, "<leader>X", "<Cmd>:bd!<CR>", { desc = "Force quit the current buffer." })
map({ "n" }, "<leader>gg", "<Cmd>:Neogit<CR>", { desc = "Open git shit" })
map("n", "<leader>gd", "<Cmd>CodeDiff<CR>", { desc = "Review Git changes" })
map({ "n" }, "<leader>u", "<Cmd>:UndotreeToggle<CR>", { desc = "Open undotree" })
map({ "n" }, "gd", vim.lsp.buf.definition, { desc = "Jump to definition" })
map({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })
map({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
map("o", "r", function() require("flash").remote() end, { desc = "Remote Flash" })
map({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter search" })
map("c", "<C-s>", function() require("flash").toggle() end, { desc = "Toggle Flash search" })

map({ "n", "v", "x" }, "<leader>gf", vim.lsp.buf.format, { desc = "Format current buffer" })
map("n", "<leader>e", "<cmd>Otree<CR>", { desc = "Toggle file tree sidebar" })
map("n", "<leader>E", function()
    require("Otree.actions").focus_tree()
    vim.api.nvim_win_set_config(0, {
        relative = "editor",
        row = 0,
        col = 0,
        width = vim.o.columns,
        height = vim.o.lines - vim.o.cmdheight,
        border = "none",
    })
end, { desc = "Open fullscreen file tree" })

vim.api.nvim_create_user_command("TermNu", function() vim.cmd("terminal nu") end, {})

local function copy_path(path, command)
    if command.range == 1 then
        path = path .. ":" .. command.line1
    elseif command.range == 2 then
        path = path .. ":" .. command.line1 .. "-" .. command.line2
    end

    vim.fn.setreg("+", path)
    vim.notify("Copied " .. path)
end

vim.api.nvim_create_user_command("CopyRelativePath", function(command)
    copy_path(vim.fn.expand("%:."), command)
end, { range = true })

vim.api.nvim_create_user_command("CopyAbsolutePath", function(command)
    copy_path(vim.fn.expand("%:p"), command)
end, { range = true })

map({ "n" }, "<leader>t", "<Cmd>:vs | TermNu<CR>", { desc = "Open terminal" })
map("t", "<C-w>n", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("n", "<leader>bc", "<Cmd>bdelete<CR>", { desc = "Close buffer" })
map("t", "<leader>bc", "<C-\\><C-n><Cmd>bdelete<CR>", { desc = "Close buffer" })

if vim.g.neovide then -- Copy paste for neovide
    map("n", "<sc-v>", 'l"+P')
    map("v", "<sc-v>", '"+P')
    map("i", "<sc-v>", '<ESC>"+p')
    map("n", "<sc-v>", '"+p')
    map("t", "<sc-v>", '<C-\\><C-n>"+Pi')

    local font_size = 20
    local function change_font_size(delta)
        font_size = math.max(1, font_size + delta)
        vim.o.guifont = "JetBrainsMono Nerd Font:h" .. font_size
    end
    change_font_size(0)

    local modes = { "n", "v", "i", "c", "t" }
    map(modes, "<D-+>", function() change_font_size(1) end, { desc = "Increase font size" })
    map(modes, "<D-=>", function() change_font_size(1) end, { desc = "Increase font size" })
    map(modes, "<D-->", function() change_font_size(-1) end, { desc = "Decrease font size" })

    vim.g.neovide_cursor_vfx_mode = "pixiedust"
    vim.g.neovide_opacity = 1.0
end

require("snacks").setup({
    input = { enabled = true },
    picker = {
        enabled = true,
        ui_select = true,
        sources = {
            neoclip = {
                title = "Clipboard history",
                finder = function()
                    local items = {}
                    for _, entry in ipairs(require("neoclip.storage").get().yanks) do
                        local text = table.concat(entry.contents, "\n")
                        items[#items + 1] = {
                            text = text,
                            preview = { text = text, ft = entry.filetype },
                            entry = entry,
                        }
                    end
                    return items
                end,
                format = "text",
                preview = "preview",
                confirm = function(picker, item)
                    picker:close()
                    if item then
                        require("neoclip.handlers").set_registers({ '"' }, item.entry)
                    end
                end,
            },
        },
        layout = {
            config = function(layout)
                layout.fullscreen = true
                local function remove_borders(box)
                    box.border = "none"
                    for _, child in ipairs(box) do
                        remove_borders(child)
                    end
                end
                remove_borders(layout.layout)
                return layout
            end,
        },
    },
})

map("n", "<leader>w", function()
    vim.wo.wrap = not vim.wo.wrap

    if vim.wo.wrap then
        map("n", "j", "gj", { buffer = true })
        map("n", "k", "gk", { buffer = true })
    else
        unmap("n", "j", { buffer = true })
        unmap("n", "k", { buffer = true })
    end
end, { desc = "Toggle wrap + visual-line movement" })

local zen = require("zen-mode")
local zen_float_shadow
zen.setup({
    border = "none",
    window = { backdrop = 1 },
    on_open = function()
        if vim.g.neovide then
            zen_float_shadow = vim.g.neovide_floating_shadow
            vim.g.neovide_floating_shadow = false
        end
    end,
    on_close = function()
        if vim.g.neovide then
            vim.g.neovide_floating_shadow = zen_float_shadow
        end
    end,
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
    zen.toggle()
end
map({ "n" }, "<leader>z", toggle_zen, { desc = "Toggle zen mode" })

-- disable ts_ls for deno project
vim.api.nvim_create_autocmd("User", {
    pattern = "LspAttach",
    callback = function()
        local cwd = vim.fn.getcwd() -- this doesn't work on macOS for some reason
        if cwd:match("slusha") then
            vim.cmd("LspStop ts_ls")
            vim.cmd("LspStart denols")
        end
    end,
})

local ts_parsers = {
    "go", "gomod", "gosum", "vim", "vimdoc", "javascript", "nix", "lua",
    "zig", "typescript", "json", "dockerfile", "sql",
    "yaml", "bash", "gitignore", "prisma", "svelte", "markdown", "markdown_inline",
}
local nts = require("nvim-treesitter")
nts.install(ts_parsers)

vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        local filetype = args.match
        local lang = vim.treesitter.language.get_lang(filetype)
        if lang and vim.treesitter.language.add(lang) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" -- indentation, provided by nvim-treesitter
            vim.treesitter.start()                                            -- syntax highlighting, provided by Neovim
        end
    end,
})
vim.api.nvim_create_user_command("SwitchToDeno", function()
    vim.cmd("LspStop ts_ls"); vim.cmd("LspStart denols")
end, {})

vim.api.nvim_create_autocmd("PackChanged", { callback = function() nts.update() end })

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*sh.example",
    callback = function()
        vim.bo.filetype = "sh"
    end,
})

require("obsidian").setup({
    workspaces = {
        {
            name = "vault",
            path = "~/Sync/shared-org",
        },
    },
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function(args)
        map("n", "gd", "<Cmd>ObsidianFollowLink<CR>", {
            buffer = args.buf,
            desc = "Follow Obsidian link",
        })
    end,
})

-- require("vague").setup({ transparent = true })
-- require("vague").setup()
-- vim.cmd("colorscheme vague")
vim.cmd("colorscheme rose-pine")
vim.api.nvim_set_hl(0, "ZenBg", { link = "Normal" })
-- vim.cmd("colorscheme monochrome")

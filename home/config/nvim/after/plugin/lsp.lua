local lsp_zero = require("lsp-zero")

lsp_zero.on_attach(function(client, bufnr)
    -- see :help lsp-zero-keybindings
    -- to learn the available actions
    lsp_zero.default_keymaps({ buffer = bufnr, preserve_mappings = false })
end)

require("mason").setup({})
require("mason-lspconfig").setup({
    ensure_installed = {},
    handlers = {
        function(server_name)
            require("lspconfig")[server_name].setup({})
        end,
    },
})

local nvim_lsp = require("lspconfig")

nvim_lsp.lua_ls.setup({})
nvim_lsp.nixd.setup({})
nvim_lsp.denols.setup({})
nvim_lsp.gopls.setup({})
nvim_lsp.golangci_lint_ls.setup({})
nvim_lsp.templ.setup({})

nvim_lsp.html.setup({
    filetypes = { "html", "templ" },
})

vim.filetype.add({ extension = { templ = "templ" } })

nvim_lsp.htmx.setup({
    filetypes = { "html", "templ" },
})

vim.api.nvim_create_autocmd({ "BufWritePre" }, { pattern = { "*.templ" }, callback = vim.lsp.buf.format })

nvim_lsp.tailwindcss.setup({
    filetypes = { "templ", "astro", "javascript", "typescript", "react" },
    init_options = { userLanguages = { templ = "html" } },
})

local cmp = require("cmp")
local cmp_action = lsp_zero.cmp_action()

require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
    -- https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/doc/md/autocomplete.md#adding-a-source
    sources = {
        { name = "copilot" },
        { name = "path" },
        { name = "nvim_lsp" },
        { name = "luasnip", keyword_length = 2 },
        { name = "buffer",  keyword_length = 3 },
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    -- https://github.com/VonHeikemen/lsp-zero.nvim/blob/v3.x/README.md#keybindings-1
    mapping = cmp.mapping.preset.insert({
        ["<CR>"] = cmp.mapping.confirm({
            -- documentation says this is important.
            -- I don't know why.
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
        }),

        -- confirm completion item
        ["<Enter>"] = cmp.mapping.confirm({ select = true }),

        -- trigger completion menu
        ["<C-Space>"] = cmp.mapping.complete(),

        -- scroll up and down the documentation window
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),

        -- navigate between snippet placeholders
        ["<C-f>"] = cmp_action.luasnip_jump_forward(),
        ["<C-b>"] = cmp_action.luasnip_jump_backward(),
    }),
    -- note: if you are going to use lsp-kind (another plugin)
    -- replace the line below with the function from lsp-kind
    formatting = lsp_zero.cmp_format({}),
})

-- Ufo
lsp_zero.set_server_config({
    capabilities = {
        textDocument = {
            foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
            },
        },
    },
})

lsp_zero.configure("denols", {
    root_dir = nvim_lsp.util.root_pattern("deno.json"),
    init_options = {
        lint = true,
        unstable = true,
        suggest = {
            imports = {
                hosts = {
                    ["https://deno.land"] = true,
                    ["https://cdn.nest.land"] = true,
                    ["https://crux.land"] = true,
                },
            },
        },
    },
    on_attach = function()
        local active_clients = vim.lsp.get_clients()
        for _, client in pairs(active_clients) do
            -- stop tsserver if denols is already active
            if client.name == "tsserver" then
                client.stop()
            end
        end
    end,
})

lsp_zero.configure("beancount", {
    init_options = {
        journal_file = "~/Sync/Shared org/beancount/kek.beancount",
    },
    autostart = true,
})

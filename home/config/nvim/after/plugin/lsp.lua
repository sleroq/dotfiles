local cmp = require("cmp")
local lspkind = require('lspkind')

cmp.setup({
    -- Uncomment to use completion manually
    -- completion = {
    --     autocomplete = false
    -- },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    sources = {
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
        { name = 'buffer',  keyword_length = 3 },
        { name = 'path' },
    },
    mapping = cmp.mapping.preset.insert({
        ['<C-y>'] = cmp.mapping.confirm({ select = false }),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.abort(),
        ['<C-u>'] = cmp.mapping.scroll_docs(-4),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-d>'] = cmp.mapping.scroll_docs(4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
    }),
    snippet = {
        expand = function(args)
            vim.snippet.expand(args.body)
        end,
    },
    formatting = {
        format = lspkind.cmp_format({
            mode = 'symbol', -- show only symbol annotations
            maxwidth = 50,   -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            -- can also be a function to dynamically calculate max width such as
            -- maxwidth = function() return math.floor(0.45 * vim.o.columns) end,
            ellipsis_char = '...',    -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
            show_labelDetails = true, -- show labelDetails in menu. Disabled by default

            -- The function below will be called before any actual modifications from lspkind
            -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
            before = function(_, vim_item)
                return vim_item
            end
        })
    }
})

local lsp_zero = require('lsp-zero')

local lsp_attach = function(_, bufnr)
    lsp_zero.default_keymaps({
        buffer = bufnr,
        preserve_mappings = false,
    })
end

lsp_zero.extend_lspconfig({
    sign_text = true,
    lsp_attach = lsp_attach,
    capabilities = require('cmp_nvim_lsp').default_capabilities()
})

require('lspconfig').lua_ls.setup({})
require('lspconfig').denols.setup({})
require('lspconfig').lua_ls.setup({})
require('lspconfig').nixd.setup({})
require('lspconfig').denols.setup({})
require('lspconfig').gopls.setup({})
require('lspconfig').golangci_lint_ls.setup({})
require('lspconfig').marksman.setup({})

-- HTMX stuff
require('lspconfig').templ.setup({})
require('lspconfig').html.setup({ filetypes = { "html", "templ" } })
vim.filetype.add({ extension = { templ = "templ" } })
require('lspconfig').htmx.setup({ filetypes = { "html", "templ" } })
vim.api.nvim_create_autocmd({ "BufWritePre" }, { pattern = { "*.templ" }, callback = vim.lsp.buf.format })

require('lspconfig').tailwindcss.setup({
    filetypes = { "templ", "astro", "javascript", "typescript", "react" },
    init_options = { userLanguages = { templ = "html" } },
})

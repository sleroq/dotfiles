local mason_status, mason = pcall(require, 'mason')
if (not mason_status) then return end
local status, masonlsp = pcall(require, 'mason-lspconfig')
if (not status) then return end

mason.setup({
  ensure_installed = {
    -- lua stuff
    'lua-language-server', 'stylua', -- 
    -- web dev
    'css-lsp', 'html-lsp', 'typescript-language-server', --     'deno',
    'json-lsp', -- shell
    --     'shfmt',
    'shellcheck'
  }
})

masonlsp.setup({
  ensure_installed = { 'gopls', 'html', 'tsserver', 'sumneko_lua' }
})

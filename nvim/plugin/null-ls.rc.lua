local status, null_ls = pcall(require, "null-ls")
if (not status) then return end

-- local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
  sources = {
    null_ls.builtins.code_actions.eslint_d,
    null_ls.builtins.diagnostics.eslint_d,
    -- null_ls.builtins.formatting.eslint_d,
    null_ls.builtins.formatting.prettierd,

    null_ls.builtins.diagnostics.golangci_lint,

    null_ls.builtins.code_actions.shellcheck,
    null_ls.builtins.diagnostics.shellcheck,

    null_ls.builtins.completion.spell
  },

-- Formatting on save
--   on_attach = function(client, bufnr)
--       if client.supports_method("textDocument/formatting") then
--           vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
--           vim.api.nvim_create_autocmd("BufWritePre", {
--               group = augroup,
--               buffer = bufnr,
--               callback = function()
--                   -- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
--                   vim.lsp.buf.formatting_sync()
--               end,
--           })
--       end
--   end,
})

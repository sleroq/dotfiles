local ls = require "luasnip"

local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

vim.keymap.set({ "i" }, "<C-K>", function() ls.expand() end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-L>", function() ls.jump(1) end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-J>", function() ls.jump(-1) end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-E>", function()
    if ls.choice_active() then
        ls.change_choice(1)
    end
end, { silent = true })

vim.keymap.set('i', '<C-k>', function()
    if ls.jumpable(-1) then
        ls.jump(-1)
    end
end, { silent = true })

ls.add_snippets {
    s("expense", {
        t("Hello, World!"),
        i(1),
    }),
}

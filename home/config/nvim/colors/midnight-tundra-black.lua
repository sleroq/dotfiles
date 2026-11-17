vim.cmd.runtime("colors/midnight-tundra.lua")
vim.g.colors_name = "midnight-tundra-black"

for name, highlight in pairs(vim.api.nvim_get_hl(0, {})) do
    if highlight.bg then
        if highlight.fg == 0x0e141b then
            highlight.fg = highlight.bg
        end
        highlight.bg = 0x000000
        vim.api.nvim_set_hl(0, name, highlight)
    end
end

for _, name in ipairs({ "Cursor", "CursorLine", "Visual", "Search", "IncSearch", "CurSearch", "PmenuSel", "MatchParen" }) do
    local highlight = vim.api.nvim_get_hl(0, { name = name })
    highlight.underline = true
    vim.api.nvim_set_hl(0, name, highlight)
end

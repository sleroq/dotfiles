vim.o.foldcolumn = '1'
vim.o.foldlevel = 999
vim.o.foldlevelstart = 99
vim.o.foldenable = true

local handler = function(virtText, lnum, endLnum, width, truncate)
    local newVirtText = {}
    local suffix = (' 󰁂 %d '):format(endLnum - lnum)
    local sufWidth = vim.fn.strdisplaywidth(suffix)
    local targetWidth = width - sufWidth
    local curWidth = 0
    for _, chunk in ipairs(virtText) do
        local chunkText = chunk[1]
        local chunkWidth = vim.fn.strdisplaywidth(chunkText)
        if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
        else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
                suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
            end
            break
        end
        curWidth = curWidth + chunkWidth
    end
    table.insert(newVirtText, { suffix, 'MoreMsg' })
    return newVirtText
end

-- global handler
-- `handler` is the 2nd parameter of `setFoldVirtTextHandler`,
-- check out `./lua/ufo.lua` and search `setFoldVirtTextHandler` for detail.
require('ufo').setup({
    enable_get_fold_virt_text = true,
    fold_virt_text_handler = handler,
    provider_selector = function(_, _, _)
        return { 'treesitter', 'indent' }
    end,
})

-- buffer scope handler
-- will override global handler if it is existed
-- local bufnr = vim.api.nvim_get_current_buf()
-- require('ufo').setFoldVirtTextHandler(bufnr, handler)

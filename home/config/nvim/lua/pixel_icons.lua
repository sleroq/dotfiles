local icons = dofile(vim.fn.stdpath("config") .. "/pixel-icons/icons.lua")
local devicons = require("nvim-web-devicons")
local original_get_icon = devicons.get_icon

local function file_icon(name)
    name = vim.fn.fnamemodify(name, ":t")
    local icon = icons.fileNames[name]
    if icon then return icon end
    for dot in name:gmatch("()%.") do
        icon = icons.fileExtensions[name:sub(dot + 1)]
        if icon then return icon end
    end
end

local function directory_icon(name)
    return icons.folderNames[vim.fn.fnamemodify(name, ":t")] or icons.folder
end

devicons.get_icon = function(name, ...)
    local _, highlight = original_get_icon(name, ...)
    return file_icon(name) or icons.file, highlight or "Normal"
end

local oil_util = require("oil.util")
local original_oil_provider = oil_util.get_icon_provider
oil_util.get_icon_provider = function()
    local original = original_oil_provider()
    return function(kind, name, ...)
        if kind == "directory" then return directory_icon(name), "Directory" end
        return original(kind, name, ...)
    end
end

local fff_icons = require("fff.file_picker.icons")
fff_icons.get_directory_icon = function(name)
    return directory_icon(name), "Directory"
end

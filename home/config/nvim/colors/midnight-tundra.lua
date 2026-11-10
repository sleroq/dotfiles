-- Rex's Midnight Tundra terminal palette.
vim.cmd("highlight clear")
vim.g.colors_name = "midnight-tundra"
vim.o.background = "dark"

local c = {
    bg = "#0e141b",
    fg = "#c9d4de",
    surface = "#17202a",
    selection = "#24384a",
    muted = "#4f6272",
    subtle = "#aebccb",
    red = "#d9707c",
    green = "#7fb88a",
    yellow = "#d8b174",
    blue = "#6da3cf",
    purple = "#a58cc7",
    cyan = "#6fb5b8",
    bright = "#e6eef5",
}

local groups = {
    Normal = { fg = c.fg, bg = c.bg },
    NormalFloat = { fg = c.fg, bg = c.surface },
    FloatBorder = { fg = c.muted, bg = c.surface },
    FloatTitle = { fg = c.blue, bg = c.surface, bold = true },
    Cursor = { fg = c.bg, bg = "#8fb8d8" },
    CursorLine = { bg = c.surface },
    CursorLineNr = { fg = c.yellow, bold = true },
    LineNr = { fg = c.muted },
    SignColumn = { bg = c.bg },
    Folded = { fg = c.subtle, bg = c.surface },
    Visual = { bg = c.selection },
    Search = { fg = c.bg, bg = c.yellow },
    IncSearch = { fg = c.bg, bg = c.cyan },
    CurSearch = { fg = c.bg, bg = c.cyan },
    Pmenu = { fg = c.fg, bg = c.surface },
    PmenuSel = { fg = c.bright, bg = c.selection },
    PmenuSbar = { bg = c.surface },
    PmenuThumb = { bg = c.muted },
    StatusLine = { fg = c.fg, bg = c.selection },
    StatusLineNC = { fg = c.muted, bg = c.surface },
    WinSeparator = { fg = c.muted },
    VertSplit = { fg = c.muted },
    TabLine = { fg = c.subtle, bg = c.surface },
    TabLineSel = { fg = c.bright, bg = c.selection, bold = true },
    TabLineFill = { bg = c.surface },
    NonText = { fg = c.muted },
    SpecialKey = { fg = c.muted },
    Directory = { fg = c.blue },
    Title = { fg = c.blue, bold = true },
    MatchParen = { fg = c.bright, bg = c.selection, bold = true },
    Comment = { fg = c.muted, italic = true },
    Constant = { fg = c.yellow },
    String = { fg = c.green },
    Character = { fg = c.green },
    Number = { fg = c.yellow },
    Identifier = { fg = c.fg },
    Function = { fg = c.blue },
    Statement = { fg = c.purple },
    Operator = { fg = c.cyan },
    PreProc = { fg = c.purple },
    Type = { fg = c.cyan },
    Special = { fg = c.red },
    Underlined = { fg = c.blue, underline = true },
    Error = { fg = c.red },
    Todo = { fg = c.yellow, bold = true },
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.yellow },
    DiagnosticInfo = { fg = c.blue },
    DiagnosticHint = { fg = c.cyan },
    DiffAdd = { fg = c.green, bg = c.surface },
    DiffChange = { fg = c.blue, bg = c.surface },
    DiffDelete = { fg = c.red, bg = c.surface },
    DiffText = { fg = c.bright, bg = c.selection },
}

for group, highlight in pairs(groups) do
    vim.api.nvim_set_hl(0, group, highlight)
end

local ansi = {
    c.surface, c.red, c.green, c.yellow, c.blue, c.purple, c.cyan, c.subtle,
    c.muted, "#e88a95", "#99cfa3", "#e8c88f", "#8abde4", "#bda6dd", "#8cced0", c.bright,
}
for i, color in ipairs(ansi) do
    vim.g["terminal_color_" .. (i - 1)] = color
end

---@class ui.icons
local M = {
    TUI = {
        Ellipsis = '…',
        CollapsedGroup = '',
        ExpandedGroup = '',
        LineContinuation = '↳',
        LineEnd = '⏎',
        VisibleSpace = '·',
        VisibleTab = '▶',
        MissingLine = '╱',
        IndentLevel = '│',
        PromptPrefix = '',
        SelectionPrefix = '',
        StrongPrefix = '▸',
        StrongSuffix = '◂',
        ListSeparator = '◦',
        ScrollLine = '▒',
        ScrollView = '█',
    },
    Diagnostics = {
        Prefix = '●',
        LSP = {
            Error = '',
            Warn = '',
            Hint = '',
            Info = '',
        },
        DAP = {
            Stopped = '󰁕',
            Breakpoint = '',
            BreakpointCondition = '',
            BreakpointRejected = '',
            LogPoint = '.>',
        },
    },
    Symbols = {
        Array = '󰅪',
        Boolean = '⊨',
        Class = '󰌗',
        Color = '',
        Constant = '',
        Constructor = '',
        Copilot = '',
        Enum = '',
        EnumMember = '',
        Event = '',
        Field = '',
        File = '',
        Folder = '',
        Function = '',
        Interface = '',
        Key = '󰌆',
        Keyword = '',
        Method = '',
        Module = '',
        Namespace = '',
        Null = 'NULL',
        Number = '',
        Object = '',
        Operator = '',
        Package = '',
        Property = '',
        Reference = '',
        Snippet = '',
        String = '󰀬',
        Struct = '',
        Text = '',
        TypeParameter = '',
        Unit = '',
        Value = '',
        Variable = '',
        ColumnSeparator = '│',
    },
    Git = {
        Added = '',
        Modified = '',
        Removed = '',
        Branch = '',
        Conflict = '',
        Ignored = '◌',
        Renamed = '➜',
        Staged = '✓',
        Unstaged = '✗',
        Untracked = '★',
        Signs = {
            Add = '▐',
            Change = '▐',
            Delete = '▐',
            TopDelete = '▐',
            ChangeDelete = '▐',
            Untracked = '▐',
        },
    },
    Dependencies = {
        Installed = '✓',
        Uninstalled = '✗',
        Pending = '⟳',
    },
    Files = {
        Normal = '󰈙',
        Multiple = ' ',
        Modified = '',
        ClosedFolder = '',
        EmptyFolder = '',
        OpenFolder = '',
        Previous = '',
    },
    UI = {
        LSP = '',
        Format = '󰉿',
        Lint = '',
        Git = '󰊢',
        Debugger = '',
        ConsoleLog = '',
        Test = '󱐦',
        UI = '󰏖',
        Help = '󰋖',
        Buffers = '󱂬',
        Search = '',
        Fix = '󰁨',
        Next = '󰼧',
        Prev = '󰒮',
        Jump = '󱔕',
        Sleep = '󰒲 ',
        Quit = ' ',
        Explorer = ' ',
        Speed = '⚡',
        Clock = '',
        Replace = '󰛔',
        Disabled = '✗',
        AI = '󱐏 ',
        Notes = '󰠮',
        IgnoreHidden = '󰛑',
        ShowHidden = '󰛐',
        SyntaxTree = '󱘎',
        TMux = '',
        Switch = '',
        Action = '󰜎',
        Nuke = '󰔒',
        SpellCheck = '󰓆',
        TypoCheck = '',
        Save = '󰆓',
        SaveAll = '󰆔',
        Close = '',
        CloseAll = '',
        SessionSave = '󰆓',
        SessionRestore = '󰆔',
        SessionDelete = '󰆴',
        Toggle = '',
        CodeLens = '󰧶',
        Macro = '󱛟',
        Checkmark = '✓',
        Tool = '󱁤',
    },
    Progress = {
        '⣾',
        '⣽',
        '⣻',
        '⢿',
        '⡿',
        '⣟',
        '⣯',
        '⣷',
    },
}

---@type boolean|nil # Whether or not the dev-icons are available
local dev_icons_available = nil

--- Get the icon and highlight for a file
---@param path string # The name of the file
---@return string, string # The icon and highlight
function M.get_file_icon(path)
    if vim.fn.isdirectory(path) == 1 then
        return M.Files.ClosedFolder, 'Normal'
    end

    if dev_icons_available == nil then
        local has_dev_icons, dev_icons = pcall(require, 'nvim-web-devicons')

        if has_dev_icons then
            if not dev_icons.has_loaded() then
                dev_icons.setup()
            end
        end

        dev_icons_available = has_dev_icons
    end

    if dev_icons_available and path and #path > 0 then
        local dev_icons = require 'nvim-web-devicons'
        local split = require('core.utils').split_path(path)

        local icon, icon_highlight = dev_icons.get_icon(split.base_name, split.compound_extension, { default = false })

        if not icon then
            icon, icon_highlight = dev_icons.get_icon(split.base_name, nil, { default = true })
            icon = icon or M.Files.Normal
        end

        return icon, icon_highlight
    else
        return M.Files.Normal, 'Normal'
    end
end

--- Fits the icon to the given width.
---@param icon string # The icon to fit
---@param width number # The width to fit the icon to
---@param ltr boolean|nil # Whether or not the icon should be left-to-right
---@return string # The fitted icon
function M.fit(icon, width, ltr)
    assert(type(icon) == 'string' and #icon > 0)
    assert(type(width) == 'number' and width > 0)
    assert(ltr == nil or type(ltr) == 'boolean')

    local w = vim.fn.strwidth(icon)
    if w < width then
        if ltr then
            return string.rep(' ', width - w) .. icon
        else
            return icon .. string.rep(' ', width - w)
        end
    else
        return icon
    end
end

--- Prepends an icon to a text
---@param icon string # The icon to prepend
---@param text string # The text to prepend the icon to
---@return string # The iconified text
function M.iconify(icon, text)
    assert(type(text) == 'string' and #text > 0)
    return M.fit(icon, 2) .. text
end

return M

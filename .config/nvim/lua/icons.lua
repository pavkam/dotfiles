-- TODO: export this as a global

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
        Test = '',
        UI = '󰏖',
        Help = '󰋖',
        Buffers = '󱂬',
        Search = '',
        Fix = '󰁨',
        Next = '󰼧',
        Prev = '󰒮',
        Jump = '󱔕',
        Quit = ' ',
        Explorer = ' ',
        Replace = '󰛔',
        Tree = '󱏒',
        Disabled = '✗',
        Error = '',
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

--- Get the icon and highlight for a file.
---@param path string # the name of the file.
---@param width number|nil # the width to fit the icon to
---@param ltr boolean|nil # whether or not the icon should be left-to-right (default false).
---@return string, string # the icon and highlight group
function M.get_file_icon(path, width, ltr)
    ---@type fun(icon: string): string
    local fit = width ~= nil and function(ic)
        return M.fit(ic, width, ltr)
    end or function(ic)
        return ic
    end

    if IDE.fs:is_directory(path) then
        return fit(M.Files.ClosedFolder), 'Normal'
    end

    if path and #path > 0 then
        local base_name = vim.fs.basename(path)
        local ext = base_name:match('%.([^%.]+)$')
        local icon = IDE.icons:for_file(base_name, ext, { default = true })
        return fit(icon:char()), icon:hl() or 'Normal'
    end

    return fit(M.Files.Normal), 'Normal'
end

---@param tool string # The name of the tool
function M.get_tool_icon(tool)
    if string.starts_with(tool, 'prettier') then
        return ''
    elseif string.starts_with(tool, 'eslint') then
        return ''
    elseif tool == 'luacheck' then
        return M.UI.Lint
    elseif tool == 'stylua' or tool == 'injected' then
        return M.UI.Lint
    end

    return M.UI.Tool
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

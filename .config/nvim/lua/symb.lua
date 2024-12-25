local tools_to_file_type = {
    ['eslint'] = 'javascript',
    ['eslint_d'] = 'javascript',
    ['prettier'] = 'javascript',
    ['prettierd'] = 'javascript',
    ['prettier_d'] = 'javascript',
    ['rustfmt'] = 'rust',
    ['gofmt'] = 'go',
    ['gofumpt'] = 'go',
    ['gofumports'] = 'go',
    ['golines'] = 'go',
    ['golangci_lint'] = 'go',
    ['vtsls'] = 'typescript',
    ['stylua'] = 'lua',
    ['shfmt'] = 'sh',
    ['black'] = 'python',
    ['isort'] = 'python',
    ['csharpier'] = 'csharp',
    ['buf'] = 'proto',
    ['markdownlint'] = 'markdown',
}

---@alias symb_icon # A string that represents an icon.
---| string # the icon.
---| { [1]:string, hl: string } # the icon with a highlight group.

ide.theme.register_highlight_groups {
    LinterTool = { 'Statement', { italic = true } },
    FormatterTool = { 'Function', { italic = true } },
    LspTool = 'PreProc',
}

---@class symb
local M = {
    progress = {
        default = {
            '⣾',
            '⣽',
            '⣻',
            '⢿',
            '⡿',
            '⣟',
            '⣯',
            '⣷',
        },
    },
    tools = {
        ---@type table<string, symb_icon>
        formatter = setmetatable({}, {
            __index = function()
                return { '󰉿', hl = 'FormatterTool' }
            end,
            __metatable = false,
        }),
        ---@type table<string, symb_icon>
        linter = setmetatable({}, {
            __index = function()
                return { '', hl = 'LinterTool' }
            end,
            __metatable = false,
        }),
        ---@type table<string, symb_icon>
        lsp = setmetatable({}, {
            __index = function()
                return { '', hl = 'LspTool' }
            end,
            __metatable = false,
        }),
    },
}

return table.freeze(M)

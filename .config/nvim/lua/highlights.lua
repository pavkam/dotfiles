local utils = require 'utils'

local function hl(name, ...)
    local m = utils.tbl_merge(...)

    vim.api.nvim_set_hl(0, name, m)
end

-- copilot highlights

hl('CopilotAnnotation', utils.hl 'Comment', { fg = '#7287fd' })
hl('CopilotSuggestion', utils.hl 'Comment', { fg = '#7287fd' })
hl('CopilotIdle', utils.hl 'Special', { bg = '#1e2030' })
hl('CopilotFetching', utils.hl 'DiagnosticWarn', { bg = '#1e2030' })
hl('CopilotWarning', utils.hl 'DiagnosticError', { bg = '#1e2030' })

hl('ShellProgressStatus', { fg = '#CC3300', ctermfg = 3, bg = '#1e2030', underdotted = true })
hl('ActiveLintersStatus', { fg = '#ff9999', ctermfg = 4, bg = '#1e2030', italic = true })
hl('ActiveFormattersStatus', { fg = '#e699ff', ctermfg = 4, bg = '#1e2030', italic = true })
hl('ActiveLSPsStatus', { fg = '#339933', ctermfg = 5, bg = '#1e2030' })

hl('DisabledLintersStatus', utils.hl 'ActiveLinters', { strikethrough = true })
hl('DisabledFormattersStatus', utils.hl 'ActiveFormatters', { strikethrough = true })

hl('IgnoreHiddenFilesStatus', { fg = '#66004d', ctermfg = 5, bg = '#1e2030', bold = true })
hl('UpdatesAvailableStatus', { fg = '#3385ff', bg = '#1e2030' })

local utils = require 'utils'

local function hl(name, ...)
    local m = utils.tbl_merge(...)

    vim.api.nvim_set_hl(0, name, m)
end

-- copilot highlights

hl('CopilotAnnotation', utils.hl 'Comment', { fg = '#7287fd' })
hl('CopilotSuggestion', utils.hl 'Comment', { fg = '#7287fd' })
hl('CopilotIdle', utils.hl 'Special')
hl('CopilotFetching', utils.hl 'DiagnosticWarn')
hl('CopilotWarning', utils.hl 'DiagnosticError')

-- other highlights
hl('ShellProgressStatus', utils.hl 'Comment')

hl('ActiveLintersStatus', utils.hl 'Statement', { italic = true })
hl('DisabledLintersStatus', utils.hl 'ActiveLintersStatus', { strikethrough = true })

hl('ActiveFormattersStatus', utils.hl 'Function', { italic = true })
hl('DisabledFormattersStatus', utils.hl 'ActiveFormattersStatus', { strikethrough = true })

hl('ActiveLSPsStatus', utils.hl 'PreProc')

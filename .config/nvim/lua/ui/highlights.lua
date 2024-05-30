local utils = require 'core.utils'

local function hl(name, ...)
    local m = utils.tbl_merge(...)

    vim.api.nvim_set_hl(0, name, m)
end

-- copilot highlights
local comment_hl = utils.hl 'Comment'

hl('CopilotAnnotation', comment_hl, { fg = '#7287fd' })
hl('CopilotSuggestion', comment_hl, { fg = '#7287fd' })
hl('CopilotIdle', utils.hl 'Special')
hl('CopilotFetching', utils.hl 'DiagnosticWarn')
hl('CopilotWarning', utils.hl 'DiagnosticError')

-- other highlights
hl('AuxiliaryProgressStatus', comment_hl)

hl('ActiveLintersStatus', utils.hl 'Statement', { italic = true })
hl('DisabledLintersStatus', utils.hl 'ActiveLintersStatus', { strikethrough = true })

hl('ActiveFormattersStatus', utils.hl 'Function', { italic = true })
hl('DisabledFormattersStatus', utils.hl 'ActiveFormattersStatus', { strikethrough = true })

hl('ActiveLSPsStatus', utils.hl 'PreProc')

hl('MarkSign', { fg = '#ff966c' })

hl('NormalMenuItem', utils.hl 'Special')
hl('SpecialMenuItem', utils.hl 'Boolean')

hl('RecordingMacroStatus', { bold = true, fg = '#ff007c' })

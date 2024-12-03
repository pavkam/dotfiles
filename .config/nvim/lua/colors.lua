local hl = require 'hl'

ide.events.colors_change
    .continue(function()
        hl.make_hls {
            CopilotAnnotation = '@string.regexp',
            CopilotSuggestion = '@string.regexp',
            NormalMenuItem = 'Special',
            SpecialMenuItem = 'Boolean',
            AuxiliaryProgressStatus = 'Comment',
            ActiveLintersStatus = { 'Statement', { italic = true } },
            DisabledLintersStatus = { 'ActiveLintersStatus', { strikethrough = true } },
            ActiveFormattersStatus = { 'Function', { italic = true } },
            DisabledFormattersStatus = { 'ActiveFormattersStatus', { strikethrough = true } },
            ActiveLSPsStatus = 'PreProc',
            CopilotIdle = 'Special',
            CopilotFetching = 'DiagnosticWarn',
            CopilotWarning = 'DiagnosticError',
            RecordingMacroStatus = { 'Error', { bold = true } },
            MarkSign = 'DiagnosticWarn',

            CommandPaletteNearFile = 'TelescopeResultsNormal',
            CommandPaletteMarkedFile = 'DiagnosticWarn',
            CommandPaletteOldFile = 'DiagnosticHint',
            CommandPaletteCommand = 'Function',
            CommandPaletteKeymap = 'Keyword',

            FilePaletteOpenFile = '@lsp.type.variable',
            FilePaletteJumpedFile = '@lsp.type.decorator',
            FilePaletteOldFile = '@lsp.type.number',
            FilePaletteMarkedFile = '@keyword',

            StatusLineTestFailed = 'NeotestFailed',
            StatusLineTestPassed = 'NeotestPassed',
            StatusLineTestSkipped = 'NeotestSkipped',
        }
    end)
    .trigger()

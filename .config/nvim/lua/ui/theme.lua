local hl = require 'ui.hl'

---@class ui.theme
local M = {}

---@type table<string, table|string>
M.colors = {
    none = 'NONE',
    bg_dark = '#1f2335',
    bg = '#24283b',
    bg_highlight = '#292e42',
    terminal_black = '#414868',
    fg = '#c0caf5',
    fg_dark = '#a9b1d6',
    fg_gutter = '#3b4261',
    dark3 = '#545c7e',
    diff = {
        add = '#2e3d49',
        change = '#394b70',
        delete = '#4b526d',
        text = '#7aa2f7',
    },
    comment = '#565f89',
    dark5 = '#737aa2',
    blue0 = '#3d59a1',
    blue = '#7aa2f7',
    cyan = '#7dcfff',
    blue1 = '#2ac3de',
    blue2 = '#0db9d7',
    blue5 = '#89ddff',
    blue6 = '#b4f9f8',
    blue7 = '#394b70',
    magenta = '#bb9af7',
    magenta2 = '#ff007c',
    purple = '#9d7cd8',
    orange = '#ff9e64',
    yellow = '#e0af68',
    green = '#9ece6a',
    green1 = '#73daca',
    green2 = '#41a6b5',
    teal = '#1abc9c',
    red = '#f7768e',
    red1 = '#db4b4b',
    git = { change = '#6183bb', add = '#449dab', delete = '#914c54' },
    gitSigns = {
        add = '#266d6a',
        change = '#536c9e',
        delete = '#b2555b',
    },
}

M.colors.todo = M.colors.blue
M.colors.warning = M.colors.yellow
M.colors.info = M.colors.blue2
M.colors.hint = M.colors.teal

---@type table<string, string|table>
M.highlights = {
    Comment = { fg = M.colors.comment, italic = true },
    ColorColumn = { bg = M.colors.black },
    Conceal = { fg = M.colors.dark5 },
    Cursor = { fg = M.colors.bg, bg = M.colors.fg },
    lCursor = { fg = M.colors.bg, bg = M.colors.fg },
    CursorIM = { fg = M.colors.bg, bg = M.colors.fg },
    CursorColumn = { bg = M.colors.bg_highlight },
    CursorLine = { bg = M.colors.bg_highlight },
    Directory = { fg = M.colors.blue },
    DiffAdd = { bg = M.colors.diff.add },
    DiffChange = { bg = M.colors.diff.change },
    DiffDelete = { bg = M.colors.diff.delete },
    DiffText = { bg = M.colors.diff.text },
    EndOfBuffer = { fg = M.colors.bg },
    ErrorMsg = { fg = M.colors.error },
    VertSplit = { fg = M.colors.border },
    WinSeparator = { fg = M.colors.border, bold = true },
    Folded = { fg = M.colors.blue, bg = M.colors.fg_gutter },
    FoldColumn = { bg = M.colors.bg, fg = M.colors.comment },
    SignColumn = { bg = M.colors.bg, fg = M.colors.fg_gutter },
    SignColumnSB = { bg = M.colors.bg_sidebar, fg = M.colors.fg_gutter },
    Substitute = { bg = M.colors.red, fg = M.colors.black },
    LineNr = { fg = M.colors.fg_gutter },
    CursorLineNr = { fg = M.colors.orange, bold = true },
    LineNrAbove = { fg = M.colors.fg_gutter },
    LineNrBelow = { fg = M.colors.fg_gutter },
    MatchParen = { fg = M.colors.orange, bold = true },
    ModeMsg = { fg = M.colors.fg_dark, bold = true },
    MsgArea = { fg = M.colors.fg_dark },
    MoreMsg = { fg = M.colors.blue },
    NonText = { fg = M.colors.dark3 },
    Normal = { fg = M.colors.fg, bg = M.colors.bg },
    NormalNC = { fg = M.colors.fg, bg = M.colors.bg },
    NormalSB = { fg = M.colors.fg_sidebar, bg = M.colors.bg_sidebar },
    NormalFloat = { fg = M.colors.fg_float, bg = M.colors.bg_float },
    FloatBorder = { fg = M.colors.border_highlight, bg = M.colors.bg_float },
    FloatTitle = { fg = M.colors.border_highlight, bg = M.colors.bg_float },
    Pmenu = { bg = M.colors.bg_popup, fg = M.colors.fg },
    PmenuSel = { bg = hl.darken(M.colors.fg_gutter, 0.8) },
    PmenuSbar = { bg = hl.lighten(M.colors.bg_popup, 0.95) },
    PmenuThumb = { bg = M.colors.fg_gutter },
    Question = { fg = M.colors.blue },
    QuickFixLine = { bg = M.colors.bg_visual, bold = true },
    Search = { bg = M.colors.bg_search, fg = M.colors.fg },
    IncSearch = { bg = M.colors.orange, fg = M.colors.black },
    CurSearch = 'IncSearch',
    SpecialKey = { fg = M.colors.dark3 },
    SpellBad = { sp = M.colors.error, undercurl = true },
    SpellCap = { sp = M.colors.warning, undercurl = true },
    SpellLocal = { sp = M.colors.info, undercurl = true },
    SpellRare = { sp = M.colors.hint, undercurl = true },
    StatusLineNC = { fg = M.colors.fg_gutter, bg = M.colors.bg_statusline },
    TabLine = { bg = M.colors.bg_statusline, fg = M.colors.fg_gutter },
    TabLineFill = { bg = M.colors.black },
    TabLineSel = { fg = M.colors.black, bg = M.colors.blue },
    Title = { fg = M.colors.blue, bold = true },
    Visual = { bg = M.colors.bg_visual },
    VisualNOS = { bg = M.colors.bg_visual },
    WarningMsg = { fg = M.colors.warning },
    Whitespace = { fg = M.colors.fg_gutter },
    WildMenu = { bg = M.colors.bg_visual },
    WinBar = 'StatusLine',
    WinBarNC = 'StatusLineNC',

    Constant = { fg = M.colors.orange },
    String = { fg = M.colors.green },
    Character = { fg = M.colors.green },
    Number = 'Constant',
    Boolean = 'Constant',
    Float = 'Constant',
    Identifier = { fg = M.colors.magenta },
    Function = { fg = M.colors.blue },
    Statement = { fg = M.colors.magenta },
    Conditional = 'Statement',
    Repeat = 'Statement',
    Label = 'Statement',
    Operator = { fg = M.colors.blue5 },

    Keyword = { fg = M.colors.cyan },
    Exception = 'Keyword',

    PreProc = { fg = M.colors.cyan },
    Include = 'PreProc',
    Define = 'PreProc',
    Macro = 'PreProc',
    PreCondit = 'PreProc',

    Type = { fg = M.colors.blue1 },
    StorageClass = 'Type',
    Structure = 'Type',
    Typedef = 'Type',

    Special = { fg = M.colors.blue1 },
    SpecialChar = 'Special',
    Tag = 'Special',
    Delimiter = 'Special',
    SpecialComment = 'Special',

    Debug = { fg = M.colors.orange },

    Underlined = { underline = true },

    Bold = { bold = true, fg = M.colors.fg },

    Italic = { italic = true, fg = M.colors.fg },

    Ignore = 'hlIgnore',

    Error = { fg = M.colors.error },

    Todo = { bg = M.colors.yellow, fg = M.colors.bg },

    qfLineNr = { fg = M.colors.dark5 },
    qfFileName = { fg = M.colors.blue },

    htmlH1 = { fg = M.colors.magenta, bold = true },
    htmlH2 = { fg = M.colors.blue, bold = true },

    mkdHeading = { fg = M.colors.orange, bold = true },
    mkdCode = { bg = M.colors.terminal_black, fg = M.colors.fg },
    mkdCodeDelimiter = { bg = M.colors.terminal_black, fg = M.colors.fg },
    mkdCodeStart = { fg = M.colors.teal, bold = true },
    mkdCodeEnd = { fg = M.colors.teal, bold = true },
    mkdLink = { fg = M.colors.blue, underline = true },

    markdownHeadingDelimiter = { fg = M.colors.orange, bold = true },
    markdownCode = { fg = M.colors.teal },
    markdownCodeBlock = { fg = M.colors.teal },
    markdownH1 = { fg = M.colors.magenta, bold = true },
    markdownH2 = { fg = M.colors.blue, bold = true },
    markdownLinkText = { fg = M.colors.blue, underline = true },

    ['helpCommand'] = { bg = M.colors.terminal_black, fg = M.colors.blue },

    debugPC = { bg = M.colors.bg_sidebar },
    debugBreakpoint = { bg = hl.darken(M.colors.info, 0.1), fg = M.colors.info },

    dosIniLabel = '@property',

    LspReferenceText = { bg = M.colors.fg_gutter },
    LspReferenceRead = { bg = M.colors.fg_gutter },
    LspReferenceWrite = { bg = M.colors.fg_gutter },

    DiagnosticError = { fg = M.colors.error },
    DiagnosticWarn = { fg = M.colors.warning },
    DiagnosticInfo = { fg = M.colors.info },
    DiagnosticHint = { fg = M.colors.hint },
    DiagnosticUnnecessary = { fg = M.colors.terminal_black },

    DiagnosticVirtualTextError = { bg = hl.darken(M.colors.error, 0.1), fg = M.colors.error },
    DiagnosticVirtualTextWarn = { bg = hl.darken(M.colors.warning, 0.1), fg = M.colors.warning },
    DiagnosticVirtualTextInfo = { bg = hl.darken(M.colors.info, 0.1), fg = M.colors.info },
    DiagnosticVirtualTextHint = { bg = hl.darken(M.colors.hint, 0.1), fg = M.colors.hint },

    DiagnosticUnderlineError = { undercurl = true, sp = M.colors.error },
    DiagnosticUnderlineWarn = { undercurl = true, sp = M.colors.warning },
    DiagnosticUnderlineInfo = { undercurl = true, sp = M.colors.info },
    DiagnosticUnderlineHint = { undercurl = true, sp = M.colors.hint },

    LspSignatureActiveParameter = { bg = hl.darken(M.colors.bg_visual, 0.4), bold = true },
    LspCodeLens = { fg = M.colors.comment },
    LspInlayHint = { bg = hl.darken(M.colors.blue7, 0.1), fg = M.colors.dark3 },

    LspInfoBorder = { fg = M.colors.border_highlight, bg = M.colors.bg_float },

    ALEErrorSign = { fg = M.colors.error },
    ALEWarningSign = { fg = M.colors.warning },

    DapStoppedLine = { bg = hl.darken(M.colors.warning, 0.1) },

    -- These groups are for the Neovim tree-sitter highlights.
    ['@annotation'] = 'PreProc',
    ['@attribute'] = 'PreProc',
    ['@boolean'] = 'Boolean',
    ['@character'] = 'Character',
    ['@character.special'] = 'SpecialChar',
    ['@character.printf'] = 'SpecialChar',
    ['@comment'] = 'Comment',
    ['@keyword.conditional'] = 'Conditional',
    ['@constant'] = 'Constant',
    ['@constant.builtin'] = 'Special',
    ['@constant.macro'] = 'Define',
    ['@keyword.debug'] = 'Debug',
    ['@keyword.directive.define'] = 'Define',
    ['@keyword.exception'] = 'Exception',
    ['@number.float'] = 'Float',
    ['@function'] = 'Function',
    ['@function.builtin'] = 'Special',
    ['@function.call'] = '@function',
    ['@function.macro'] = 'Macro',
    ['@keyword.import'] = 'Include',
    ['@keyword.coroutine'] = '@keyword',
    ['@keyword.operator'] = '@operator',
    ['@keyword.return'] = '@keyword',
    ['@function.method'] = 'Function',
    ['@function.method.call'] = '@function.method',
    ['@namespace.builtin'] = '@variable.builtin',
    ['@none'] = {},
    ['@number'] = 'Number',
    ['@keyword.directive'] = 'PreProc',
    ['@keyword.repeat'] = 'Repeat',
    ['@keyword.storage'] = 'StorageClass',
    ['@string'] = 'String',
    ['@markup.link.label'] = 'SpecialChar',
    ['@markup.link.label.symbol'] = 'Identifier',
    ['@tag'] = 'Label',
    ['@tag.attribute'] = '@property',
    ['@tag.delimiter'] = 'Delimiter',
    ['@markup'] = '@none',
    ['@markup.environment'] = 'Macro',
    ['@markup.environment.name'] = 'Type',
    ['@markup.raw'] = 'String',
    ['@markup.math'] = 'Special',
    ['@markup.strong'] = '@true',
    ['@markup.emphasis'] = { italic = true },
    ['@markup.italic'] = { italic = true },
    ['@markup.strikethrough'] = { strikethrough = true },
    ['@markup.underline'] = { underline = true },
    ['@markup.heading'] = 'Title',
    ['@comment.note'] = { fg = M.colors.hint },
    ['@comment.error'] = { fg = M.colors.error },
    ['@comment.hint'] = { fg = M.colors.hint },
    ['@comment.info'] = { fg = M.colors.info },
    ['@comment.warning'] = { fg = M.colors.warning },
    ['@comment.todo'] = { fg = M.colors.todo },
    ['@markup.link.url'] = 'Underlined',
    ['@type'] = 'Type',
    ['@type.definition'] = 'Typedef',
    ['@type.qualifier'] = '@keyword',

    ['@operator'] = { fg = M.colors.blue5 },

    --- Punctuation
    ['@punctuation.delimiter'] = { fg = M.colors.blue5 },
    ['@punctuation.bracket'] = { fg = M.colors.fg_dark },
    ['@punctuation.special'] = { fg = M.colors.blue5 },
    ['@markup.list'] = { fg = M.colors.blue5 },
    ['@markup.list.markdown'] = { fg = M.colors.orange, bold = true },

    --- Literals
    ['@string.documentation'] = { fg = M.colors.yellow },
    ['@string.regexp'] = { fg = M.colors.blue6 },
    ['@string.escape'] = { fg = M.colors.magenta },

    --- Functions
    ['@constructor'] = { fg = M.colors.magenta },
    ['@variable.parameter'] = { fg = M.colors.yellow },
    ['@variable.parameter.builtin'] = { fg = hl.lighten(M.colors.yellow, 0.8) },

    --- Keywords
    ['@keyword'] = { fg = M.colors.purple },
    ['@keyword.function'] = { fg = M.colors.magenta },

    ['@label'] = { fg = M.colors.blue },

    --- Types
    ['@type.builtin'] = { fg = hl.darken(M.colors.blue1, 0.8) },
    ['@variable.member'] = { fg = M.colors.green1 }, -- For fields.
    ['@property'] = { fg = M.colors.green1 },

    --- Identifiers
    ['@variable'] = { fg = M.colors.fg },
    ['@variable.builtin'] = { fg = M.colors.red },
    ['@module.builtin'] = { fg = M.colors.red },

    --- Text
    ['@markup.raw.markdown'] = { fg = M.colors.blue },
    ['@markup.raw.markdown_inline'] = { bg = M.colors.terminal_black, fg = M.colors.blue },
    ['@markup.link'] = { fg = M.colors.teal },
    ['@markup.list.unchecked'] = { fg = M.colors.blue },
    ['@markup.list.checked'] = { fg = M.colors.green1 },

    ['@diff.plus'] = 'DiffAdd',
    ['@diff.minus'] = 'DiffDelete',
    ['@diff.delta'] = 'DiffChange',

    ['@module'] = 'Include',

    -- tsx
    ['@tag.tsx'] = { fg = M.colors.red },
    ['@constructor.tsx'] = { fg = M.colors.blue1 },
    ['@tag.delimiter.tsx'] = { fg = hl.darken(M.colors.blue, 0.7) },

    -- LSP Semantic Token Groups
    ['@lsp.type.boolean'] = '@boolean',
    ['@lsp.type.builtinType'] = '@type.builtin',
    ['@lsp.type.comment'] = '@comment',
    ['@lsp.type.decorator'] = '@attribute',
    ['@lsp.type.deriveHelper'] = '@attribute',
    ['@lsp.type.enum'] = '@type',
    ['@lsp.type.enumMember'] = '@constant',
    ['@lsp.type.escapeSequence'] = '@string.escape',
    ['@lsp.type.formatSpecifier'] = '@markup.list',
    ['@lsp.type.generic'] = '@variable',
    ['@lsp.type.interface'] = { fg = hl.lighten(M.colors.blue1, 0.7) },
    ['@lsp.type.keyword'] = '@keyword',
    ['@lsp.type.lifetime'] = '@keyword.storage',
    ['@lsp.type.namespace'] = '@module',
    ['@lsp.type.number'] = '@number',
    ['@lsp.type.operator'] = '@operator',
    ['@lsp.type.parameter'] = '@variable.parameter',
    ['@lsp.type.property'] = '@property',
    ['@lsp.type.selfKeyword'] = '@variable.builtin',
    ['@lsp.type.selfTypeKeyword'] = '@variable.builtin',
    ['@lsp.type.string'] = '@string',
    ['@lsp.type.typeAlias'] = '@type.definition',
    ['@lsp.type.unresolvedReference'] = { undercurl = true, sp = M.colors.error },
    ['@lsp.type.variable'] = {},
    ['@lsp.typemod.class.defaultLibrary'] = '@type.builtin',
    ['@lsp.typemod.enum.defaultLibrary'] = '@type.builtin',
    ['@lsp.typemod.enumMember.defaultLibrary'] = '@constant.builtin',
    ['@lsp.typemod.function.defaultLibrary'] = '@function.builtin',
    ['@lsp.typemod.keyword.async'] = '@keyword.coroutine',
    ['@lsp.typemod.keyword.injected'] = '@keyword',
    ['@lsp.typemod.macro.defaultLibrary'] = '@function.builtin',
    ['@lsp.typemod.method.defaultLibrary'] = '@function.builtin',
    ['@lsp.typemod.operator.injected'] = '@operator',
    ['@lsp.typemod.string.injected'] = '@string',
    ['@lsp.typemod.struct.defaultLibrary'] = '@type.builtin',
    ['@lsp.typemod.type.defaultLibrary'] = { fg = hl.darken(M.colors.blue1, 0.8) },
    ['@lsp.typemod.typeAlias.defaultLibrary'] = { fg = hl.darken(M.colors.blue1, 0.8) },
    ['@lsp.typemod.variable.callable'] = '@function',
    ['@lsp.typemod.variable.defaultLibrary'] = '@variable.builtin',
    ['@lsp.typemod.variable.injected'] = '@variable',
    ['@lsp.typemod.variable.static'] = '@constant',

    -- Python
    ['@lsp.type.namespace.python'] = '@variable',

    -- diff
    diffAdded = { fg = M.colors.git.add },
    diffRemoved = { fg = M.colors.git.delete },
    diffChanged = { fg = M.colors.git.change },
    diffOldFile = { fg = M.colors.yellow },
    diffNewFile = { fg = M.colors.orange },
    diffFile = { fg = M.colors.blue },
    diffLine = { fg = M.colors.comment },
    diffIndexLine = { fg = M.colors.magenta },

    -- Neotest
    NeotestPassed = { fg = M.colors.green },
    NeotestRunning = { fg = M.colors.yellow },
    NeotestFailed = { fg = M.colors.red },
    NeotestSkipped = { fg = M.colors.blue },
    NeotestTest = { fg = M.colors.fg_sidebar },
    NeotestNamespace = { fg = M.colors.green2 },
    NeotestFocused = { fg = M.colors.yellow },
    NeotestFile = { fg = M.colors.teal },
    NeotestDir = { fg = M.colors.blue },
    NeotestBorder = { fg = M.colors.blue },
    NeotestIndent = { fg = M.colors.fg_sidebar },
    NeotestExpandMarker = { fg = M.colors.fg_sidebar },
    NeotestAdapterName = { fg = M.colors.purple, bold = true },
    NeotestWinSelect = { fg = M.colors.blue },
    NeotestMarked = { fg = M.colors.blue },
    NeotestTarget = { fg = M.colors.blue },
    NeotestUnknown = {},

    -- GitSigns
    GitSignsAdd = { fg = M.colors.gitSigns.add },
    GitSignsChange = { fg = M.colors.gitSigns.change },
    GitSignsDelete = { fg = M.colors.gitSigns.delete },

    -- Telescope
    TelescopeBorder = { fg = M.colors.border_highlight, bg = M.colors.bg_float },
    TelescopeNormal = { fg = M.colors.fg, bg = M.colors.bg_float },
    TelescopePromptBorder = { fg = M.colors.orange, bg = M.colors.bg_float },
    TelescopePromptTitle = { fg = M.colors.orange, bg = M.colors.bg_float },
    TelescopeResultsComment = { fg = M.colors.dark3 },

    -- Neo-Tree
    NeoTreeNormal = { fg = M.colors.fg_sidebar, bg = M.colors.bg_sidebar },
    NeoTreeNormalNC = { fg = M.colors.fg_sidebar, bg = M.colors.bg_sidebar },
    NeoTreeDimText = { fg = M.colors.fg_gutter },
    NeoTreeGitModified = { fg = M.colors.orange },
    NeoTreeGitUntracked = { fg = M.colors.magenta },
    NeoTreeGitStaged = { fg = M.colors.green1 },
    NeoTreeFileName = { fg = M.colors.fg_sidebar },

    -- glyph palette
    GlyphPalette1 = { fg = M.colors.red1 },
    GlyphPalette2 = { fg = M.colors.green },
    GlyphPalette3 = { fg = M.colors.yellow },
    GlyphPalette4 = { fg = M.colors.blue },
    GlyphPalette6 = { fg = M.colors.green1 },
    GlyphPalette7 = { fg = M.colors.fg },
    GlyphPalette9 = { fg = M.colors.red },

    -- Alpha
    AlphaShortcut = { fg = M.colors.orange },
    AlphaHeader = { fg = M.colors.blue },
    AlphaHeaderLabel = { fg = M.colors.orange },
    AlphaFooter = { fg = M.colors.blue1 },
    AlphaButtons = { fg = M.colors.cyan },

    -- WhichKey
    WhichKey = { fg = M.colors.cyan },
    WhichKeyGroup = { fg = M.colors.blue },
    WhichKeyDesc = { fg = M.colors.magenta },
    WhichKeySeparator = { fg = M.colors.comment },
    WhichKeyFloat = { bg = M.colors.bg_sidebar },
    WhichKeyValue = { fg = M.colors.dark5 },

    -- NeoVim
    healthError = { fg = M.colors.error },
    healthSuccess = { fg = M.colors.green1 },
    healthWarning = { fg = M.colors.warning },

    -- Cmp
    CmpDocumentation = { fg = M.colors.fg, bg = M.colors.bg_float },
    CmpDocumentationBorder = { fg = M.colors.border_highlight, bg = M.colors.bg_float },
    CmpGhostText = { fg = M.colors.terminal_black },
    CmpItemAbbr = { fg = M.colors.fg, bg = M.colors.none },
    CmpItemAbbrDeprecated = { fg = M.colors.fg_gutter, bg = M.colors.none, strikethrough = true },
    CmpItemAbbrMatch = { fg = M.colors.blue1, bg = M.colors.none },
    CmpItemAbbrMatchFuzzy = { fg = M.colors.blue1, bg = M.colors.none },
    CmpItemMenu = { fg = M.colors.comment, bg = M.colors.none },
    CmpItemKindDefault = { fg = M.colors.fg_dark, bg = M.colors.none },
    CmpItemKindCodeium = { fg = M.colors.teal, bg = M.colors.none },
    CmpItemKindCopilot = { fg = M.colors.teal, bg = M.colors.none },
    CmpItemKindTabNine = { fg = M.colors.teal, bg = M.colors.none },

    -- headlines
    CodeBlock = { bg = M.colors.bg_dark },

    -- Lazy
    LazyProgressDone = { bold = true, fg = M.colors.magenta2 },
    LazyProgressTodo = { bold = true, fg = M.colors.fg_gutter },

    -- Notify
    NotifyBackground = { fg = M.colors.fg, bg = M.colors.bg },
    NotifyERRORBorder = { fg = hl.darken(M.colors.error, 0.3), bg = M.colors.bg },
    NotifyWARNBorder = { fg = hl.darken(M.colors.warning, 0.3), bg = M.colors.bg },
    NotifyINFOBorder = { fg = hl.darken(M.colors.info, 0.3), bg = M.colors.bg },
    NotifyDEBUGBorder = { fg = hl.darken(M.colors.comment, 0.3), bg = M.colors.bg },
    NotifyTRACEBorder = { fg = hl.darken(M.colors.purple, 0.3), bg = M.colors.bg },
    NotifyERRORIcon = { fg = M.colors.error },
    NotifyWARNIcon = { fg = M.colors.warning },
    NotifyINFOIcon = { fg = M.colors.info },
    NotifyDEBUGIcon = { fg = M.colors.comment },
    NotifyTRACEIcon = { fg = M.colors.purple },
    NotifyERRORTitle = { fg = M.colors.error },
    NotifyWARNTitle = { fg = M.colors.warning },
    NotifyINFOTitle = { fg = M.colors.info },
    NotifyDEBUGTitle = { fg = M.colors.comment },
    NotifyTRACETitle = { fg = M.colors.purple },
    NotifyERRORBody = { fg = M.colors.fg, bg = M.colors.bg },
    NotifyWARNBody = { fg = M.colors.fg, bg = M.colors.bg },
    NotifyINFOBody = { fg = M.colors.fg, bg = M.colors.bg },
    NotifyDEBUGBody = { fg = M.colors.fg, bg = M.colors.bg },
    NotifyTRACEBody = { fg = M.colors.fg, bg = M.colors.bg },

    -- Noice
    NoiceCompletionItemKindDefault = { fg = M.colors.fg_dark, bg = M.colors.none },
    NoiceCmdlineIconLua = { fg = M.colors.blue1 },
    NoiceCmdlinePopupBorderLua = { fg = M.colors.blue1 },
    NoiceCmdlinePopupTitleLua = { fg = M.colors.blue1 },
    NoiceCmdlineIconInput = { fg = M.colors.yellow },
    NoiceCmdlinePopupBorderInput = { fg = M.colors.yellow },
    NoiceCmdlinePopupTitleInput = { fg = M.colors.yellow },
    TreesitterContext = { bg = hl.darken(M.colors.fg_gutter, 0.8) },
    Hlargs = { fg = M.colors.yellow },

    -- Other
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
}

---@type table<string, string>
local kinds = {
    Array = '@punctuation.bracket',
    Boolean = '@boolean',
    Class = '@type',
    Color = 'Special',
    Constant = '@constant',
    Constructor = '@constructor',
    Enum = '@lsp.type.enum',
    EnumMember = '@lsp.type.enumMember',
    Event = 'Special',
    Field = '@variable.member',
    File = 'Normal',
    Folder = 'Directory',
    Function = '@function',
    Interface = '@lsp.type.interface',
    Key = '@variable.member',
    Keyword = '@lsp.type.keyword',
    Method = '@function.method',
    Module = '@module',
    Namespace = '@module',
    Null = '@constant.builtin',
    Number = '@number',
    Object = '@constant',
    Operator = '@operator',
    Package = '@module',
    Property = '@property',
    Reference = '@markup.link',
    Snippet = 'Conceal',
    String = '@string',
    Struct = '@lsp.type.struct',
    Unit = '@lsp.type.struct',
    Text = '@markup',
    TypeParameter = '@lsp.type.typeParameter',
    Variable = '@variable',
    Value = '@string',
}

---@type table<string, string>
local kind_groups = { 'CmpItemKind%s', 'NoiceCompletionItemKind%s' }
for kind, link in pairs(kinds) do
    local base = 'LspKind' .. kind
    M.highlights[base] = link
    for _, plugin in pairs(kind_groups) do
        M.highlights[plugin:format(kind)] = base
    end
end

---@type string[]
local markdown_rainbow =
    { M.colors.blue, M.colors.yellow, M.colors.green, M.colors.teal, M.colors.magenta, M.colors.purple }

for i, color in ipairs(markdown_rainbow) do
    M.highlights['@markup.heading.' .. i .. '.markdown'] = { fg = color, bold = true }
    M.highlights['Headline' .. i] = { bg = hl.darken(color, 0.05) }
end

M.highlights['Headline'] = 'Headline1'

if not vim.diagnostic then
    local severity_map = {
        Error = 'Error',
        Warn = 'Warning',
        Info = 'Information',
        Hint = 'Hint',
    }

    local types = { 'Default', 'VirtualText', 'Underline' }

    for _, type in ipairs(types) do
        for snew, sold in pairs(severity_map) do
            M.highlights['LspDiagnostics' .. type .. sold] = 'Diagnostic' .. (type == 'Default' and '' or type) .. snew
        end
    end
end

for x, def in pairs(M.highlights) do
    if type(def) == 'string' then
        hl.make_hl(x, def)
    elseif type(def) == 'table' and type(def[1]) == 'string' then
        local link = def[1]
        local opts = def[2]

        hl.make_hl(x, link, opts)
    else
        hl.make_hl(x, def)
    end
end

M.lualine = {
    normal = {
        a = { bg = M.colors.blue, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.blue },
        c = { bg = M.colors.bg_statusline, fg = M.colors.fg_sidebar },
    },

    insert = {
        a = { bg = M.colors.green, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.green },
    },

    command = {
        a = { bg = M.colors.yellow, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.yellow },
    },

    visual = {
        a = { bg = M.colors.magenta, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.magenta },
    },

    replace = {
        a = { bg = M.colors.red, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.red },
    },

    terminal = {
        a = { bg = M.colors.green1, fg = M.colors.black },
        b = { bg = M.colors.fg_gutter, fg = M.colors.green1 },
    },

    inactive = {
        a = { bg = M.colors.bg_statusline, fg = M.colors.blue },
        b = { bg = M.colors.bg_statusline, fg = M.colors.fg_gutter, gui = 'bold' },
        c = { bg = M.colors.bg_statusline, fg = M.colors.fg_gutter },
    },
}

return M

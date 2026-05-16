-- TurboVision Colorscheme — complete owned colorscheme replacing tokyonight.nvim
-- Palette: dark navy/blue backgrounds with modern 24-bit syntax colors inspired by
-- the Tokyo Night Moon palette but shifted toward a TurboVision aesthetic.
-- Chrome groups (IDE* prefixed) are set by the turbovision_theme extension.

local M = {}

-- ── Palette ────────────────────────────────────────────────────────
-- TurboVision-authentic colors: deep blue editor background (CGA blue),
-- bright readable syntax colors inspired by the classic 16-color CGA palette
-- but extended to 24-bit for modern readability.

M.palette = {
    -- ── Editor backgrounds (CGA dark blue family) ──
    bg              = '#0a0e2a',  -- main editor: very dark navy (CGA blue, darkened)
    bg_dark         = '#060920',  -- sidebars, floats, statusline
    bg_darker       = '#040716',  -- tabline fill
    bg_highlight    = '#162044',  -- cursorline: slightly lighter navy
    bg_visual       = '#1a3070',  -- visual selection: brighter blue
    bg_search       = '#2850a0',  -- search highlight
    bg_popup        = '#0c1030',  -- popup menu
    bg_gutter       = '#0a0e2a',  -- sign/fold column: same as editor

    -- ── Editor foregrounds ──
    fg              = '#E0E0E0',  -- main text: bright white-ish (CGA white)
    fg_dark         = '#A0A0B0',  -- dimmed text
    fg_gutter       = '#404880',  -- line numbers
    fg_sidebar      = '#8888AA',  -- sidebar text
    fg_comment      = '#5566AA',  -- comments: medium blue-gray
    fg_nontext      = '#303860',  -- non-text chars
    fg_dim          = '#6670A0',  -- concealed

    -- ── Borders ──
    border          = '#4488CC',  -- window separators
    border_hl       = '#5599DD',  -- float borders

    -- ── Syntax colors (CGA-inspired, brightened for readability) ──
    blue            = '#55AAFF',  -- functions (CGA bright blue)
    blue_bright     = '#66CCFF',  -- types, specials
    blue_deep       = '#2850A0',  -- search bg
    blue_sky        = '#88DDFF',  -- operators
    blue_ice        = '#AAEEFF',  -- string.regexp
    blue_muted      = '#203050',  -- inlay hint bg
    cyan            = '#55FFFF',  -- keywords (CGA bright cyan)
    teal            = '#00CCAA',  -- properties, hints
    green           = '#55FF55',  -- strings (CGA bright green)
    green_bright    = '#33AA88',  -- neotest
    yellow          = '#FFFF55',  -- warnings, params (CGA bright yellow)
    orange          = '#FFAA55',  -- constants, numbers
    red             = '#FF5555',  -- errors, deletions (CGA bright red)
    red_deep        = '#CC3333',  -- diagnostic error
    magenta         = '#FF55FF',  -- statements (CGA bright magenta)
    purple          = '#AA88FF',  -- keywords
    pink            = '#FF55AA',  -- accent

    -- ── Terminal colors ──
    terminal_black  = '#334466',  -- ghost text

    -- ── Git ──
    git_add         = '#55CC55',
    git_change      = '#5588DD',
    git_delete      = '#CC4444',
    git_ignore      = '#445566',

    -- ── Diff backgrounds ──
    diff_add_bg     = '#0a2a1a',
    diff_change_bg  = '#0a1a2a',
    diff_delete_bg  = '#2a0a1a',
    diff_text_bg    = '#1a2a4a',

    -- ── Diagnostics ──
    diag_error      = '#FF4444',
    diag_warn       = '#FFAA33',
    diag_info       = '#44AAFF',
    diag_hint       = '#33CCAA',
    diag_ok         = '#55CC55',
    diag_deprecated = '#CC8888',

    -- ── Diagnostic virtual text backgrounds (blended) ──
    diag_error_bg   = '#1a0a14',
    diag_warn_bg    = '#1a1408',
    diag_info_bg    = '#081420',
    diag_hint_bg    = '#081a1a',

    -- ── Markdown rainbow headings ──
    rainbow = {
        '#55AAFF', '#FFFF55', '#55FF55', '#00CCAA',
        '#FF55FF', '#AA88FF', '#FFAA55', '#FF5555',
    },

    -- ── Markdown heading backgrounds ──
    rainbow_bg = {
        '#0a1430', '#1a1a08', '#0a1a0a', '#081a1a',
        '#1a0a1a', '#100a1a', '#1a1008', '#1a0a0a',
    },

    -- ── Misc ──
    none            = 'NONE',
}

-- ── Highlight definitions ──────────────────────────────────────────
-- Returns a flat table of { GroupName = { fg=, bg=, ... } }.
-- String values mean "link to that group".

function M.highlights()
    local p = M.palette

    -- helper: blend a color into bg at ~10% (pre-computed above for perf)
    local hl = {}

    -- ════════════════════════════════════════════════════════════════
    -- 1. EDITOR UI
    -- ════════════════════════════════════════════════════════════════

    hl['Normal']          = { fg = p.fg, bg = p.bg }
    hl['NormalNC']        = { fg = p.fg, bg = p.bg }
    hl['NormalFloat']     = { fg = p.fg, bg = p.bg_popup }
    hl['NormalSB']        = { fg = p.fg_sidebar, bg = p.bg_dark }
    hl['Cursor']          = { fg = p.bg, bg = p.fg }
    hl['lCursor']         = { fg = p.bg, bg = p.fg }
    hl['CursorIM']        = { fg = p.bg, bg = p.fg }
    hl['CursorLine']      = { bg = p.bg_highlight }
    hl['CursorColumn']    = { bg = p.bg_highlight }
    hl['CursorLineNr']    = { fg = p.orange, bold = true }
    hl['CursorLineFold']  = { link = 'CursorLine' }
    hl['CursorLineSign']  = { link = 'CursorLine' }
    hl['ColorColumn']     = { bg = p.bg_darker }
    hl['Visual']          = { bg = p.bg_visual }
    hl['VisualNOS']       = { bg = p.bg_visual }
    hl['Search']          = { fg = p.fg, bg = p.bg_search }
    hl['IncSearch']       = { fg = p.bg_darker, bg = p.orange }
    hl['CurSearch']       = { link = 'IncSearch' }
    hl['Substitute']      = { fg = p.bg_darker, bg = p.red }
    hl['LineNr']          = { fg = p.fg_gutter }
    hl['LineNrAbove']     = { fg = p.fg_gutter }
    hl['LineNrBelow']     = { fg = p.fg_gutter }
    hl['SignColumn']      = { fg = p.fg_gutter, bg = p.bg }
    hl['SignColumnSB']    = { fg = p.fg_gutter, bg = p.bg_dark }
    hl['VertSplit']       = { fg = p.border }
    hl['WinSeparator']    = { fg = p.border, bold = true }
    hl['Folded']          = { fg = p.blue, bg = p.bg_gutter }
    hl['FoldColumn']      = { fg = p.fg_comment, bg = p.bg }
    hl['EndOfBuffer']     = { fg = p.bg }
    hl['NonText']         = { fg = p.fg_nontext }
    hl['SpecialKey']      = { fg = p.fg_nontext }
    hl['Whitespace']      = { fg = p.fg_gutter }
    hl['Conceal']         = { fg = p.fg_dim }
    hl['MatchParen']      = { fg = p.orange, bold = true }
    hl['Directory']       = { fg = p.blue }
    hl['Title']           = { fg = p.blue, bold = true }
    hl['ModeMsg']         = { fg = p.fg_dark, bold = true }
    hl['MsgArea']         = { fg = p.fg_dark }
    hl['MoreMsg']         = { fg = p.blue }
    hl['ErrorMsg']        = { fg = p.diag_error }
    hl['WarningMsg']      = { fg = p.diag_warn }
    hl['OkMsg']           = { fg = p.diag_ok }
    hl['Question']        = { fg = p.blue }
    hl['QuickFixLine']    = { bg = p.bg_visual, bold = true }
    hl['WildMenu']        = { bg = p.bg_visual }
    hl['TermCursor']      = { reverse = true }
    hl['FloatBorder']     = { fg = p.border_hl, bg = p.bg_popup }
    hl['FloatTitle']      = { fg = p.border_hl, bg = p.bg_popup }
    hl['FloatFooter']     = { fg = p.border_hl, bg = p.bg_popup }
    hl['FloatShadow']     = { bg = '#4f5258' }
    hl['FloatShadowThrough'] = { bg = '#4f5258' }

    -- ── Popup menu ──
    hl['Pmenu']           = { fg = p.fg, bg = p.bg_popup }
    hl['PmenuSel']        = { bg = '#363c58' }
    hl['PmenuMatch']      = { fg = p.blue_bright, bg = p.bg_popup }
    hl['PmenuMatchSel']   = { fg = p.blue_bright, bg = '#363c58' }
    hl['PmenuSbar']       = { bg = '#27293a' }
    hl['PmenuThumb']      = { bg = p.bg_gutter }
    hl['PmenuBorder']     = { fg = p.border_hl, bg = p.bg_popup }
    hl['PmenuKind']       = { fg = p.fg_dim, bg = p.bg_popup }
    hl['PmenuKindSel']    = { fg = p.fg_dim, bg = '#363c58' }
    hl['PmenuExtra']      = { fg = p.fg_comment, bg = p.bg_popup }
    hl['PmenuExtraSel']   = { fg = p.fg_comment, bg = '#363c58' }
    hl['PmenuShadow']     = { bg = '#4f5258' }
    hl['PmenuShadowThrough'] = { bg = '#4f5258' }

    -- ── Status / Tab / WinBar (base — overridden by turbovision_theme extension) ──
    hl['StatusLine']      = { fg = p.fg_sidebar, bg = p.bg_dark }
    hl['StatusLineNC']    = { fg = p.fg_gutter, bg = p.bg_dark }
    hl['TabLine']         = { fg = p.fg_gutter, bg = p.bg_dark }
    hl['TabLineFill']     = { bg = p.bg_darker }
    hl['TabLineSel']      = { fg = p.bg_darker, bg = p.blue }
    hl['WinBar']          = { link = 'StatusLine' }
    hl['WinBarNC']        = { link = 'StatusLineNC' }

    -- ── Spell ──
    hl['SpellBad']        = { sp = p.diag_error, undercurl = true }
    hl['SpellCap']        = { sp = p.diag_warn, undercurl = true }
    hl['SpellLocal']      = { sp = p.diag_info, undercurl = true }
    hl['SpellRare']       = { sp = p.diag_hint, undercurl = true }

    -- ── Snippet ──
    hl['SnippetTabstop']       = { link = 'Visual' }
    hl['SnippetTabstopActive'] = { link = 'Visual' }

    -- ── Redraw debug ──
    hl['RedrawDebugClear']     = { bg = '#6b5300' }
    hl['RedrawDebugComposed']  = { bg = '#005523' }
    hl['RedrawDebugNormal']    = { reverse = true }
    hl['RedrawDebugRecompose'] = { bg = '#590008' }

    -- ── Misc formatting ──
    hl['Bold']            = { fg = p.fg, bold = true }
    hl['Italic']          = { fg = p.fg, italic = true }
    hl['Underlined']      = { underline = true }

    -- ════════════════════════════════════════════════════════════════
    -- 2. SYNTAX (vim legacy highlight groups)
    -- ════════════════════════════════════════════════════════════════

    hl['Comment']         = { fg = p.fg_comment, italic = true }
    hl['String']          = { fg = p.green }
    hl['Character']       = { fg = p.green }
    hl['Number']          = { link = 'Constant' }
    hl['Float']           = { link = 'Number' }
    hl['Boolean']         = { link = 'Constant' }
    hl['Constant']        = { fg = p.orange }
    hl['Identifier']      = { fg = p.magenta }
    hl['Function']        = { fg = p.blue }
    hl['Statement']       = { fg = p.magenta }
    hl['Conditional']     = { link = 'Statement' }
    hl['Repeat']          = { link = 'Statement' }
    hl['Label']           = { link = 'Statement' }
    hl['Exception']       = { link = 'Statement' }
    hl['Operator']        = { fg = p.blue_sky }
    hl['Keyword']         = { fg = p.cyan, italic = true }
    hl['PreProc']         = { fg = p.cyan }
    hl['Include']         = { link = 'PreProc' }
    hl['Define']          = { link = 'PreProc' }
    hl['PreCondit']       = { link = 'PreProc' }
    hl['Macro']           = { link = 'PreProc' }
    hl['Type']            = { fg = p.blue_bright }
    hl['Typedef']         = { link = 'Type' }
    hl['StorageClass']    = { link = 'Type' }
    hl['Structure']       = { link = 'Type' }
    hl['Special']         = { fg = p.blue_bright }
    hl['SpecialChar']     = { link = 'Special' }
    hl['SpecialComment']  = { link = 'Special' }
    hl['Tag']             = { link = 'Special' }
    hl['Delimiter']       = { link = 'Special' }
    hl['Debug']           = { fg = p.orange }
    hl['Error']           = { fg = p.diag_error }
    hl['Todo']            = { fg = p.bg, bg = p.yellow }
    hl['Ignore']          = {} -- hidden text

    -- ════════════════════════════════════════════════════════════════
    -- 3. TREESITTER (@-prefixed groups)
    -- ════════════════════════════════════════════════════════════════

    -- Annotations & Attributes
    hl['@annotation']                   = { link = 'PreProc' }
    hl['@attribute']                    = { link = 'PreProc' }
    hl['@attribute.builtin']            = { link = 'PreProc' }

    -- Booleans, Characters
    hl['@boolean']                      = { link = 'Boolean' }
    hl['@character']                    = { link = 'Character' }
    hl['@character.printf']             = { link = 'SpecialChar' }
    hl['@character.special']            = { link = 'SpecialChar' }

    -- Comments
    hl['@comment']                      = { link = 'Comment' }
    hl['@comment.error']                = { fg = p.diag_error }
    hl['@comment.hint']                 = { fg = p.diag_hint }
    hl['@comment.info']                 = { fg = p.diag_info }
    hl['@comment.note']                 = { fg = p.diag_hint }
    hl['@comment.todo']                 = { fg = p.blue }
    hl['@comment.warning']              = { fg = p.diag_warn }

    -- Constants
    hl['@constant']                     = { link = 'Constant' }
    hl['@constant.builtin']             = { link = 'Special' }
    hl['@constant.macro']               = { link = 'Define' }

    -- Constructors
    hl['@constructor']                  = { fg = p.magenta }
    hl['@constructor.tsx']              = { fg = p.blue_bright }

    -- Diff
    hl['@diff.delta']                   = { link = 'DiffChange' }
    hl['@diff.minus']                   = { link = 'DiffDelete' }
    hl['@diff.plus']                    = { link = 'DiffAdd' }

    -- Functions
    hl['@function']                     = { link = 'Function' }
    hl['@function.builtin']             = { link = 'Special' }
    hl['@function.call']                = { link = '@function' }
    hl['@function.macro']               = { link = 'Macro' }
    hl['@function.method']              = { link = 'Function' }
    hl['@function.method.call']         = { link = '@function.method' }

    -- Keywords
    hl['@keyword']                      = { fg = p.purple, italic = true }
    hl['@keyword.conditional']          = { link = 'Conditional' }
    hl['@keyword.coroutine']            = { link = '@keyword' }
    hl['@keyword.debug']                = { link = 'Debug' }
    hl['@keyword.directive']            = { link = 'PreProc' }
    hl['@keyword.directive.define']     = { link = 'Define' }
    hl['@keyword.exception']            = { link = 'Exception' }
    hl['@keyword.function']             = { fg = p.magenta }
    hl['@keyword.import']               = { link = 'Include' }
    hl['@keyword.operator']             = { link = '@operator' }
    hl['@keyword.repeat']               = { link = 'Repeat' }
    hl['@keyword.return']               = { link = '@keyword' }
    hl['@keyword.storage']              = { link = 'StorageClass' }

    -- Labels
    hl['@label']                        = { fg = p.blue }

    -- Markup (markdown, vimdoc, etc.)
    hl['@markup']                       = { link = '@none' }
    hl['@markup.emphasis']              = { italic = true }
    hl['@markup.environment']           = { link = 'Macro' }
    hl['@markup.environment.name']      = { link = 'Type' }
    hl['@markup.heading']               = { link = 'Title' }
    hl['@markup.italic']                = { italic = true }
    hl['@markup.link']                  = { fg = p.teal }
    hl['@markup.link.label']            = { link = 'SpecialChar' }
    hl['@markup.link.label.symbol']     = { link = 'Identifier' }
    hl['@markup.link.url']              = { link = 'Underlined' }
    hl['@markup.list']                  = { fg = p.blue_sky }
    hl['@markup.list.checked']          = { fg = p.teal }
    hl['@markup.list.markdown']         = { fg = p.orange, bold = true }
    hl['@markup.list.unchecked']        = { fg = p.blue }
    hl['@markup.math']                  = { link = 'Special' }
    hl['@markup.raw']                   = { link = 'String' }
    hl['@markup.raw.markdown_inline']   = { fg = p.blue, bg = p.terminal_black }
    hl['@markup.strikethrough']         = { strikethrough = true }
    hl['@markup.strong']                = { bold = true }
    hl['@markup.underline']             = { underline = true }

    -- Markdown heading rainbow
    for i = 1, 8 do
        hl['@markup.heading.' .. i .. '.markdown'] = {
            fg = p.rainbow[i], bg = p.rainbow_bg[i], bold = true,
        }
    end
    -- Vimdoc heading delimiters
    hl['@markup.heading.1.delimiter.vimdoc'] = {
        fg = p.bg, bg = p.bg, sp = p.fg, nocombine = true, underdouble = true,
    }
    hl['@markup.heading.2.delimiter.vimdoc'] = {
        fg = p.bg, bg = p.bg, sp = p.fg, nocombine = true, underline = true,
    }

    -- Modules
    hl['@module']                       = { link = 'Include' }
    hl['@module.builtin']               = { fg = p.red }

    -- None
    hl['@none']                         = {}

    -- Numbers
    hl['@number']                       = { link = 'Number' }
    hl['@number.float']                 = { link = 'Float' }

    -- Operators & Punctuation
    hl['@operator']                     = { fg = p.blue_sky }
    hl['@property']                     = { fg = p.teal }
    hl['@punctuation']                  = { link = 'Delimiter' }
    hl['@punctuation.bracket']          = { fg = p.fg_dark }
    hl['@punctuation.delimiter']        = { fg = p.blue_sky }
    hl['@punctuation.special']          = { fg = p.blue_sky }
    hl['@punctuation.special.markdown'] = { fg = p.orange }

    -- Strings
    hl['@string']                       = { link = 'String' }
    hl['@string.documentation']         = { fg = p.yellow }
    hl['@string.escape']                = { fg = p.magenta }
    hl['@string.regexp']                = { fg = p.blue_ice }
    hl['@string.special']               = { link = 'Special' }
    hl['@string.special.url']           = { link = 'Underlined' }

    -- Tags (JSX/TSX/HTML)
    hl['@tag']                          = { link = 'Label' }
    hl['@tag.attribute']                = { link = '@property' }
    hl['@tag.builtin']                  = { link = 'Label' }
    hl['@tag.delimiter']                = { link = 'Delimiter' }
    hl['@tag.delimiter.tsx']            = { fg = '#6582c3' }
    hl['@tag.tsx']                      = { fg = p.red }
    hl['@tag.javascript']               = { fg = p.red }

    -- Types
    hl['@type']                         = { link = 'Type' }
    hl['@type.builtin']                 = { fg = '#589ed7' }
    hl['@type.definition']              = { link = 'Typedef' }
    hl['@type.qualifier']               = { link = '@keyword' }

    -- Variables
    hl['@variable']                     = { fg = p.fg }
    hl['@variable.builtin']             = { fg = p.red }
    hl['@variable.member']              = { fg = p.teal }
    hl['@variable.parameter']           = { fg = p.yellow }
    hl['@variable.parameter.builtin']   = { fg = '#f4c990' }

    -- Namespace (legacy alias)
    hl['@namespace.builtin']            = { link = '@variable.builtin' }

    -- ════════════════════════════════════════════════════════════════
    -- 4. LSP SEMANTIC TOKENS
    -- ════════════════════════════════════════════════════════════════

    hl['@lsp.type.boolean']                      = { link = '@boolean' }
    hl['@lsp.type.builtinType']                  = { link = '@type.builtin' }
    hl['@lsp.type.class']                        = { link = '@type' }
    hl['@lsp.type.comment']                      = { link = '@comment' }
    hl['@lsp.type.decorator']                    = { link = '@attribute' }
    hl['@lsp.type.deriveHelper']                 = { link = '@attribute' }
    hl['@lsp.type.enum']                         = { link = '@type' }
    hl['@lsp.type.enumMember']                   = { link = '@constant' }
    hl['@lsp.type.escapeSequence']               = { link = '@string.escape' }
    hl['@lsp.type.event']                        = { link = 'Special' }
    hl['@lsp.type.formatSpecifier']              = { link = '@markup.list' }
    hl['@lsp.type.function']                     = { link = '@function' }
    hl['@lsp.type.generic']                      = { link = '@variable' }
    hl['@lsp.type.interface']                    = { fg = '#83c3fc' }
    hl['@lsp.type.keyword']                      = { link = '@keyword' }
    hl['@lsp.type.lifetime']                     = { link = '@keyword.storage' }
    hl['@lsp.type.macro']                        = { link = 'Macro' }
    hl['@lsp.type.method']                       = { link = '@function.method' }
    hl['@lsp.type.modifier']                     = { link = '@keyword' }
    hl['@lsp.type.namespace']                    = { link = '@module' }
    hl['@lsp.type.namespace.python']             = { link = '@variable' }
    hl['@lsp.type.number']                       = { link = '@number' }
    hl['@lsp.type.operator']                     = { link = '@operator' }
    hl['@lsp.type.parameter']                    = { link = '@variable.parameter' }
    hl['@lsp.type.property']                     = { link = '@property' }
    hl['@lsp.type.regexp']                       = { link = '@string.regexp' }
    hl['@lsp.type.selfKeyword']                  = { link = '@variable.builtin' }
    hl['@lsp.type.selfTypeKeyword']              = { link = '@variable.builtin' }
    hl['@lsp.type.string']                       = { link = '@string' }
    hl['@lsp.type.struct']                       = { link = '@type' }
    hl['@lsp.type.type']                         = { link = '@type' }
    hl['@lsp.type.typeAlias']                    = { link = '@type.definition' }
    hl['@lsp.type.typeParameter']                = { link = '@type' }
    hl['@lsp.type.unresolvedReference']          = { sp = p.diag_error, undercurl = true }
    hl['@lsp.type.variable']                     = {} -- defer to treesitter

    hl['@lsp.mod.deprecated']                    = { strikethrough = true }

    hl['@lsp.typemod.class.defaultLibrary']      = { link = '@type.builtin' }
    hl['@lsp.typemod.enum.defaultLibrary']       = { link = '@type.builtin' }
    hl['@lsp.typemod.enumMember.defaultLibrary'] = { link = '@constant.builtin' }
    hl['@lsp.typemod.function.defaultLibrary']   = { link = '@function.builtin' }
    hl['@lsp.typemod.keyword.async']             = { link = '@keyword.coroutine' }
    hl['@lsp.typemod.keyword.injected']          = { link = '@keyword' }
    hl['@lsp.typemod.macro.defaultLibrary']      = { link = '@function.builtin' }
    hl['@lsp.typemod.method.defaultLibrary']     = { link = '@function.builtin' }
    hl['@lsp.typemod.operator.injected']         = { link = '@operator' }
    hl['@lsp.typemod.string.injected']           = { link = '@string' }
    hl['@lsp.typemod.struct.defaultLibrary']      = { link = '@type.builtin' }
    hl['@lsp.typemod.type.defaultLibrary']       = { fg = '#589ed7' }
    hl['@lsp.typemod.typeAlias.defaultLibrary']  = { fg = '#589ed7' }
    hl['@lsp.typemod.variable.callable']         = { link = '@function' }
    hl['@lsp.typemod.variable.defaultLibrary']   = { link = '@variable.builtin' }
    hl['@lsp.typemod.variable.injected']         = { link = '@variable' }
    hl['@lsp.typemod.variable.static']           = { link = '@constant' }

    -- ════════════════════════════════════════════════════════════════
    -- 5. DIAGNOSTICS
    -- ════════════════════════════════════════════════════════════════

    hl['DiagnosticError']              = { fg = p.diag_error }
    hl['DiagnosticWarn']               = { fg = p.diag_warn }
    hl['DiagnosticInfo']               = { fg = p.diag_info }
    hl['DiagnosticHint']               = { fg = p.diag_hint }
    hl['DiagnosticOk']                 = { fg = p.diag_ok }
    hl['DiagnosticUnnecessary']        = { fg = p.fg_dark }
    hl['DiagnosticDeprecated']         = { sp = p.diag_deprecated, strikethrough = true }

    hl['DiagnosticSignError']          = { link = 'DiagnosticError' }
    hl['DiagnosticSignWarn']           = { link = 'DiagnosticWarn' }
    hl['DiagnosticSignInfo']           = { link = 'DiagnosticInfo' }
    hl['DiagnosticSignHint']           = { link = 'DiagnosticHint' }
    hl['DiagnosticSignOk']             = { link = 'DiagnosticOk' }

    hl['DiagnosticFloatingError']      = { link = 'DiagnosticError' }
    hl['DiagnosticFloatingWarn']       = { link = 'DiagnosticWarn' }
    hl['DiagnosticFloatingInfo']       = { link = 'DiagnosticInfo' }
    hl['DiagnosticFloatingHint']       = { link = 'DiagnosticHint' }
    hl['DiagnosticFloatingOk']         = { link = 'DiagnosticOk' }

    hl['DiagnosticVirtualTextError']   = { fg = p.diag_error, bg = p.diag_error_bg }
    hl['DiagnosticVirtualTextWarn']    = { fg = p.diag_warn,  bg = p.diag_warn_bg }
    hl['DiagnosticVirtualTextInfo']    = { fg = p.diag_info,  bg = p.diag_info_bg }
    hl['DiagnosticVirtualTextHint']    = { fg = p.diag_hint,  bg = p.diag_hint_bg }
    hl['DiagnosticVirtualTextOk']      = { link = 'DiagnosticOk' }

    hl['DiagnosticVirtualLinesError']  = { link = 'DiagnosticVirtualTextError' }
    hl['DiagnosticVirtualLinesWarn']   = { link = 'DiagnosticVirtualTextWarn' }
    hl['DiagnosticVirtualLinesInfo']   = { link = 'DiagnosticVirtualTextInfo' }
    hl['DiagnosticVirtualLinesHint']   = { link = 'DiagnosticVirtualTextHint' }
    hl['DiagnosticVirtualLinesOk']     = { link = 'DiagnosticVirtualTextOk' }

    hl['DiagnosticUnderlineError']     = { sp = p.diag_error, undercurl = true }
    hl['DiagnosticUnderlineWarn']      = { sp = p.diag_warn,  undercurl = true }
    hl['DiagnosticUnderlineInfo']      = { sp = p.diag_info,  undercurl = true }
    hl['DiagnosticUnderlineHint']      = { sp = p.diag_hint,  undercurl = true }
    hl['DiagnosticUnderlineOk']        = { sp = p.diag_ok,    underline = true }

    -- ════════════════════════════════════════════════════════════════
    -- 6. LSP
    -- ════════════════════════════════════════════════════════════════

    hl['LspReferenceText']             = { bg = p.bg_gutter }
    hl['LspReferenceRead']             = { bg = p.bg_gutter }
    hl['LspReferenceWrite']            = { bg = p.bg_gutter }
    hl['LspReferenceTarget']           = { link = 'LspReferenceText' }
    hl['LspSignatureActiveParameter']  = { bg = '#262f50', bold = true }
    hl['LspCodeLens']                  = { fg = p.fg_comment }
    hl['LspCodeLensSeparator']         = { link = 'LspCodeLens' }
    hl['LspInlayHint']                 = { fg = p.fg_nontext, bg = '#24283c' }
    hl['LspInfoBorder']                = { fg = p.border_hl, bg = p.bg_popup }
    hl['ComplHint']                     = { fg = p.terminal_black }
    hl['ComplHintMore']                 = { link = 'ComplHint' }
    hl['ComplMatchIns']                 = { link = 'ComplHint' }
    hl['PreInsert']                     = { link = 'ComplHint' }

    -- ── LspKind (completion item kind icons) ──
    local kind_links = {
        Array = '@punctuation.bracket', Boolean = '@boolean', Class = '@type',
        Color = 'Special', Constant = '@constant', Constructor = '@constructor',
        Enum = '@lsp.type.enum', EnumMember = '@lsp.type.enumMember',
        Event = 'Special', Field = '@variable.member', File = 'Normal',
        Folder = 'Directory', Function = '@function',
        Interface = '@lsp.type.interface', Key = '@variable.member',
        Keyword = '@lsp.type.keyword', Method = '@function.method',
        Module = '@module', Namespace = '@module', Null = '@constant.builtin',
        Number = '@number', Object = '@constant', Operator = '@operator',
        Package = '@module', Property = '@property', Reference = '@markup.link',
        Snippet = 'Conceal', String = '@string', Struct = '@lsp.type.struct',
        Unit = '@lsp.type.struct', Text = '@markup',
        TypeParameter = '@lsp.type.typeParameter', Variable = '@variable',
        Value = '@string',
    }
    for kind, link in pairs(kind_links) do
        hl['LspKind' .. kind] = { link = link }
    end

    -- ════════════════════════════════════════════════════════════════
    -- 7. GIT / DIFF
    -- ════════════════════════════════════════════════════════════════

    hl['DiffAdd']         = { bg = p.diff_add_bg }
    hl['DiffChange']      = { bg = p.diff_change_bg }
    hl['DiffDelete']      = { bg = p.diff_delete_bg }
    hl['DiffText']        = { bg = p.diff_text_bg }
    hl['DiffTextAdd']     = { link = 'DiffText' }
    hl['Added']           = { fg = p.diag_ok }
    hl['Changed']         = { fg = '#8cf8f7' }
    hl['Removed']         = { fg = p.diag_deprecated }

    hl['diffAdded']       = { fg = p.git_add,    bg = p.diff_add_bg }
    hl['diffRemoved']     = { fg = p.git_delete,  bg = p.diff_delete_bg }
    hl['diffChanged']     = { fg = p.git_change,  bg = p.diff_change_bg }
    hl['diffOldFile']     = { fg = p.blue_bright, bg = p.diff_delete_bg }
    hl['diffNewFile']     = { fg = p.blue_bright, bg = p.diff_add_bg }
    hl['diffFile']        = { fg = p.blue }
    hl['diffLine']        = { fg = p.fg_comment }
    hl['diffIndexLine']   = { fg = p.magenta }

    -- ── GitSigns ──
    hl['GitSignsAdd']     = { fg = p.git_add }
    hl['GitSignsChange']  = { fg = p.git_change }
    hl['GitSignsDelete']  = { fg = p.git_delete }

    -- ════════════════════════════════════════════════════════════════
    -- 8. COMPLETION (CMP)
    -- ════════════════════════════════════════════════════════════════

    hl['CmpDocumentation']       = { fg = p.fg, bg = p.bg_popup }
    hl['CmpDocumentationBorder'] = { fg = p.border_hl, bg = p.bg_popup }
    hl['CmpGhostText']           = { fg = p.terminal_black }
    hl['CmpItemAbbr']            = { fg = p.fg }
    hl['CmpItemAbbrDeprecated']  = { fg = p.fg_gutter, strikethrough = true }
    hl['CmpItemAbbrMatch']       = { fg = p.blue_bright }
    hl['CmpItemAbbrMatchFuzzy']  = { fg = p.blue_bright }
    hl['CmpItemMenu']            = { fg = p.fg_comment }
    hl['CmpItemKindDefault']     = { fg = p.fg_dark }
    hl['CmpItemKindCodeium']     = { fg = p.teal }
    hl['CmpItemKindCopilot']     = { fg = p.teal }
    hl['CmpItemKindSupermaven']  = { fg = p.teal }
    hl['CmpItemKindTabNine']     = { fg = p.teal }
    -- CmpItemKind* (same pattern as LspKind)
    for kind, link in pairs(kind_links) do
        hl['CmpItemKind' .. kind] = { link = 'LspKind' .. kind }
    end

    -- ════════════════════════════════════════════════════════════════
    -- 9. TELESCOPE
    -- ════════════════════════════════════════════════════════════════

    hl['TelescopeBorder']           = { fg = p.border_hl, bg = p.bg_popup }
    hl['TelescopeNormal']           = { fg = p.fg, bg = p.bg_popup }
    hl['TelescopePromptBorder']     = { fg = p.orange, bg = p.bg_popup }
    hl['TelescopePromptTitle']      = { fg = p.orange, bg = p.bg_popup }
    hl['TelescopePromptNormal']     = { fg = p.fg, bg = p.bg_popup }
    hl['TelescopeResultsComment']   = { fg = p.fg_nontext }
    hl['TelescopeResultsTitle']     = { fg = p.border_hl, bg = p.bg_popup }
    hl['TelescopePreviewTitle']     = { fg = p.border_hl, bg = p.bg_popup }
    hl['TelescopePreviewBorder']    = { fg = p.border_hl, bg = p.bg_popup }
    hl['TelescopePreviewNormal']    = { fg = p.fg, bg = p.bg_popup }
    hl['TelescopeSelection']        = { bg = p.bg_highlight }
    hl['TelescopeSelectionCaret']   = { fg = p.blue }
    hl['TelescopeMatching']         = { fg = p.blue_bright, bold = true }

    -- ════════════════════════════════════════════════════════════════
    -- 10. NEO-TREE
    -- ════════════════════════════════════════════════════════════════

    hl['NeoTreeNormal']                = { fg = p.fg_sidebar, bg = p.bg_dark }
    hl['NeoTreeNormalNC']              = { fg = p.fg_sidebar, bg = p.bg_dark }
    hl['NeoTreeDimText']               = { fg = p.fg_gutter }
    hl['NeoTreeFileName']              = { fg = p.fg_sidebar }
    hl['NeoTreeGitModified']           = { fg = p.orange }
    hl['NeoTreeGitStaged']             = { fg = p.teal }
    hl['NeoTreeGitUntracked']          = { fg = p.magenta }
    hl['NeoTreeGitConflict']           = { fg = p.diag_error }
    hl['NeoTreeGitDeleted']            = { fg = p.git_delete }
    hl['NeoTreeGitAdded']              = { fg = p.git_add }
    hl['NeoTreeTabActive']             = { fg = p.blue, bg = p.bg_dark, bold = true }
    hl['NeoTreeTabInactive']           = { fg = p.fg_nontext, bg = '#171824' }
    hl['NeoTreeTabSeparatorActive']    = { fg = p.blue, bg = p.bg_dark }
    hl['NeoTreeTabSeparatorInactive']  = { fg = p.bg, bg = '#171824' }
    hl['NeoTreeRootName']              = { fg = p.blue, bold = true }
    hl['NeoTreeIndentMarker']          = { fg = p.fg_gutter }
    hl['NeoTreeExpander']              = { fg = p.fg_gutter }
    hl['NeoTreeDirectoryIcon']         = { fg = p.blue }
    hl['NeoTreeDirectoryName']         = { fg = p.blue }
    hl['NeoTreeFloatBorder']           = { fg = p.border_hl, bg = p.bg_popup }
    hl['NeoTreeFloatTitle']            = { fg = p.border_hl, bg = p.bg_popup }
    hl['NeoTreeSymbolicLinkTarget']    = { fg = p.teal }

    -- ════════════════════════════════════════════════════════════════
    -- 11. NOICE
    -- ════════════════════════════════════════════════════════════════

    hl['NoiceCmdlineIconInput']          = { fg = p.yellow }
    hl['NoiceCmdlineIconLua']            = { fg = p.blue_bright }
    hl['NoiceCmdlinePopupBorderInput']   = { fg = p.yellow }
    hl['NoiceCmdlinePopupBorderLua']     = { fg = p.blue_bright }
    hl['NoiceCmdlinePopupTitleInput']    = { fg = p.yellow }
    hl['NoiceCmdlinePopupTitleLua']      = { fg = p.blue_bright }
    hl['NoiceCompletionItemKindDefault'] = { fg = p.fg_dark }
    -- NoiceCompletionItemKind* (same kinds pattern)
    for kind, _ in pairs(kind_links) do
        hl['NoiceCompletionItemKind' .. kind] = { link = 'LspKind' .. kind }
    end

    -- ════════════════════════════════════════════════════════════════
    -- 12. NOTIFY (nvim-notify)
    -- ════════════════════════════════════════════════════════════════

    hl['NotifyBackground']    = { fg = p.fg, bg = p.bg }
    hl['NotifyINFOBorder']    = { fg = '#1b4a4a' }
    hl['NotifyINFOIcon']      = { fg = p.diag_info }
    hl['NotifyINFOTitle']     = { fg = p.diag_info }
    hl['NotifyINFOBody']      = { fg = p.fg, bg = p.bg }
    hl['NotifyWARNBorder']    = { fg = '#534825' }
    hl['NotifyWARNIcon']      = { fg = p.diag_warn }
    hl['NotifyWARNTitle']     = { fg = p.diag_warn }
    hl['NotifyWARNBody']      = { fg = p.fg, bg = p.bg }
    hl['NotifyERRORBorder']   = { fg = '#4a1d28' }
    hl['NotifyERRORIcon']     = { fg = p.diag_error }
    hl['NotifyERRORTitle']    = { fg = p.diag_error }
    hl['NotifyERRORBody']     = { fg = p.fg, bg = p.bg }
    hl['NotifyDEBUGBorder']   = { fg = '#2a2d4a' }
    hl['NotifyDEBUGIcon']     = { fg = p.fg_comment }
    hl['NotifyDEBUGTitle']    = { fg = p.fg_comment }
    hl['NotifyDEBUGBody']     = { fg = p.fg, bg = p.bg }
    hl['NotifyTRACEBorder']   = { fg = '#3a2848' }
    hl['NotifyTRACEIcon']     = { fg = p.purple }
    hl['NotifyTRACETitle']    = { fg = p.purple }
    hl['NotifyTRACEBody']     = { fg = p.fg, bg = p.bg }

    -- ════════════════════════════════════════════════════════════════
    -- 13. NEOTEST
    -- ════════════════════════════════════════════════════════════════

    hl['NeotestAdapterName']  = { fg = p.purple, bold = true }
    hl['NeotestBorder']       = { fg = p.blue }
    hl['NeotestDir']          = { fg = p.blue }
    hl['NeotestExpandMarker'] = { fg = p.fg_sidebar }
    hl['NeotestFailed']       = { fg = p.red }
    hl['NeotestFile']         = { fg = p.teal }
    hl['NeotestFocused']      = { fg = p.yellow }
    hl['NeotestIndent']       = { fg = p.fg_sidebar }
    hl['NeotestMarked']       = { fg = p.blue }
    hl['NeotestNamespace']    = { fg = p.green_bright }
    hl['NeotestPassed']       = { fg = p.green }
    hl['NeotestRunning']      = { fg = p.yellow }
    hl['NeotestSkipped']      = { fg = p.blue }
    hl['NeotestTarget']       = { fg = p.blue }
    hl['NeotestTest']         = { fg = p.fg_sidebar }
    hl['NeotestWinSelect']    = { fg = p.blue }

    -- ════════════════════════════════════════════════════════════════
    -- 14. DAP (Debug Adapter)
    -- ════════════════════════════════════════════════════════════════

    hl['DapStoppedLine']      = { bg = p.diag_warn_bg }
    hl['debugBreakpoint']     = { fg = p.diag_info, bg = p.diag_info_bg }
    hl['debugPC']             = { bg = p.bg_dark }

    -- ════════════════════════════════════════════════════════════════
    -- 15. LAZY.NVIM
    -- ════════════════════════════════════════════════════════════════

    hl['LazyProgressDone']    = { fg = p.pink, bold = true }
    hl['LazyProgressTodo']    = { fg = p.fg_gutter, bold = true }

    -- ════════════════════════════════════════════════════════════════
    -- 16. WHICH-KEY
    -- ════════════════════════════════════════════════════════════════

    hl['WhichKey']            = { fg = p.cyan }
    hl['WhichKeyGroup']       = { fg = p.blue }
    hl['WhichKeyDesc']        = { fg = p.magenta }
    hl['WhichKeySeparator']   = { fg = p.fg_comment }
    hl['WhichKeyNormal']      = { bg = p.bg_dark }
    hl['WhichKeyValue']       = { fg = p.fg_dim }

    -- ════════════════════════════════════════════════════════════════
    -- 17. INDENT BLANKLINE
    -- ════════════════════════════════════════════════════════════════

    hl['IndentBlanklineChar']        = { fg = p.fg_gutter, nocombine = true }
    hl['IndentBlanklineContextChar'] = { fg = p.blue_bright, nocombine = true }
    hl['IblIndent']                  = { fg = p.fg_gutter, nocombine = true }
    hl['IblScope']                   = { fg = p.blue_bright, nocombine = true }

    -- ════════════════════════════════════════════════════════════════
    -- 18. SUPERMAVEN
    -- ════════════════════════════════════════════════════════════════

    hl['SupermavenSuggestion']       = { fg = p.terminal_black }

    -- ════════════════════════════════════════════════════════════════
    -- 19. FLASH
    -- ════════════════════════════════════════════════════════════════

    hl['FlashBackdrop']    = { fg = p.fg_nontext }
    hl['FlashLabel']       = { fg = p.fg, bg = p.pink, bold = true }

    -- ════════════════════════════════════════════════════════════════
    -- 20. HEALTH
    -- ════════════════════════════════════════════════════════════════

    hl['healthError']      = { fg = p.diag_error }
    hl['healthSuccess']    = { fg = p.teal }
    hl['healthWarning']    = { fg = p.diag_warn }

    -- ════════════════════════════════════════════════════════════════
    -- 21. HELP / VIMDOC
    -- ════════════════════════════════════════════════════════════════

    hl['helpCommand']      = { fg = p.blue, bg = p.terminal_black }
    hl['helpExample']      = { fg = p.fg_comment }
    hl['htmlH1']           = { fg = p.magenta, bold = true }
    hl['htmlH2']           = { fg = p.blue, bold = true }

    -- ════════════════════════════════════════════════════════════════
    -- 22. QUICKFIX
    -- ════════════════════════════════════════════════════════════════

    hl['qfFileName']       = { fg = p.blue }
    hl['qfLineNr']         = { fg = p.fg_dim }

    -- ════════════════════════════════════════════════════════════════
    -- 23. DOSINI
    -- ════════════════════════════════════════════════════════════════

    hl['dosIniLabel']      = { link = '@property' }

    -- ════════════════════════════════════════════════════════════════
    -- 24. IDE KEY HINTS (IDEKeyHint*)
    -- ════════════════════════════════════════════════════════════════

    hl['IDEKeyHintKey']    = { fg = p.blue_bright, bold = true }
    hl['IDEKeyHintDesc']   = { fg = p.fg }
    hl['IDEKeyHintIcon']   = { fg = p.magenta }

    -- ════════════════════════════════════════════════════════════════
    -- 25. FOO (test highlight from tokyonight)
    -- ════════════════════════════════════════════════════════════════

    hl['Foo']              = { fg = p.fg, bg = p.pink }

    -- ════════════════════════════════════════════════════════════════
    -- 26. MASON
    -- ════════════════════════════════════════════════════════════════

    hl['MasonNormal']      = { fg = p.fg, bg = p.bg_popup }

    -- ════════════════════════════════════════════════════════════════
    -- 27. TERMINAL COLORS (g:terminal_color_*)
    -- ════════════════════════════════════════════════════════════════
    -- These are set separately via vim.g; stored here for reference.

    return hl
end

-- ── Terminal color table (16 ANSI colors) ──────────────────────────
M.terminal_colors = {
    [0]  = '#1b1d2b',  -- black
    [1]  = '#ff757f',  -- red
    [2]  = '#c3e88d',  -- green
    [3]  = '#ffc777',  -- yellow
    [4]  = '#82aaff',  -- blue
    [5]  = '#c099ff',  -- magenta
    [6]  = '#86e1fc',  -- cyan
    [7]  = '#828bb8',  -- white
    [8]  = '#444a73',  -- bright black
    [9]  = '#ff8d94',  -- bright red
    [10] = '#c7fb6d',  -- bright green
    [11] = '#ffd8ab',  -- bright yellow
    [12] = '#9ab8ff',  -- bright blue
    [13] = '#caabff',  -- bright magenta
    [14] = '#b2ebff',  -- bright cyan
    [15] = '#c8d3f5',  -- bright white
}

-- ── Apply the colorscheme ──────────────────────────────────────────

function M.apply()
    -- Reset
    if vim.g.colors_name then
        vim.cmd('hi clear')
    end
    vim.o.termguicolors = true
    vim.g.colors_name = 'turbovision'
    vim.o.background = 'dark'

    -- Set all highlight groups
    local highlights = M.highlights()
    for group, opts in pairs(highlights) do
        if type(opts) == 'string' then
            -- It's a link
            vim.api.nvim_set_hl(0, group, { link = opts })
        elseif opts.link then
            vim.api.nvim_set_hl(0, group, { link = opts.link })
        else
            vim.api.nvim_set_hl(0, group, opts)
        end
    end

    -- Set terminal colors
    for i, color in pairs(M.terminal_colors) do
        vim.g['terminal_color_' .. i] = color
    end
end

return M

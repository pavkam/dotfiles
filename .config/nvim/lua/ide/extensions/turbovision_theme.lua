-- TurboVision Theme Extension: Borland TurboVision-inspired color palettes.
-- Provides two palettes (dark and light) that override all IDE chrome highlights
-- (menus, status bar, panels, notifications) while leaving syntax highlighting
-- untouched. Dark mode replicates the classic Turbo Pascal 7.0 / Borland C++ 3.1
-- look: deep blue menu bar, cyan dropdowns, gray dialogs, yellow hotkeys.

local Extension = require 'ide.Extension'

local TurboVisionTheme = Class('TurboVisionTheme', Extension)

function TurboVisionTheme:init()
    Extension.init(self, 'TurboVisionTheme')
    self._variant = 'dark' -- 'dark' or 'light'
end

-- ── Color Palettes ──────────────────────────────────────────────

-- Classic TurboVision dark palette (Turbo Pascal 7.0 / Borland C++ 3.1)
local DARK = {
    -- Desktop / CRT phosphor colors
    navy           = '#000080',  -- deep blue (menu bar, selected item bg)
    cyan           = '#008080',  -- teal (dropdown bg)
    gray           = '#808080',  -- dialog/panel bg
    light_gray     = '#C0C0C0',  -- status bar bg, normal text on dark
    dark_gray      = '#555555',  -- disabled text
    black          = '#000000',  -- text on cyan, shadow
    white          = '#FFFFFF',  -- selected text, titles
    yellow         = '#FFFF00',  -- hotkey / accelerator letter
    bright_cyan    = '#00AAAA',  -- active menu bg in bar
    bright_white   = '#F0F0F0',  -- bright text accent

    -- Mode colors (kept vivid for clarity)
    green          = '#00AA00',  -- insert mode
    blue           = '#5555FF',  -- normal mode
    magenta        = '#AA00AA',  -- visual mode
    red            = '#FF5555',  -- replace mode
    amber          = '#FFAA00',  -- command mode
    bright_blue    = '#55AAFF',  -- terminal mode

    -- Diagnostics (slightly muted to fit the retro palette)
    diag_error     = '#FF5555',
    diag_warn      = '#FFAA00',
    diag_info      = '#55AAFF',
    diag_hint      = '#00AA88',

    -- Git diff
    diff_add       = '#00AA00',
    diff_change    = '#FFAA00',
    diff_del       = '#FF5555',

    -- Notification accents
    notify_info    = '#55AAFF',
    notify_warn    = '#FFAA00',
    notify_error   = '#FF5555',
    notify_debug   = '#AA55FF',

    -- Panel borders
    border_gray    = '#999999',
    panel_bg       = '#707070',
    panel_title_fg = '#FFFFFF',

    -- Status bar
    status_bg      = '#C0C0C0',
    status_fg      = '#000000',
    status_dim     = '#404040',
    ai_purple      = '#AA55FF',
}

-- TurboVision light variant (for bright terminal backgrounds)
local LIGHT = {
    navy           = '#0000AA',
    cyan           = '#55CCCC',
    gray           = '#C0C0C0',
    light_gray     = '#E8E8E8',
    dark_gray      = '#888888',
    black          = '#000000',
    white          = '#FFFFFF',
    yellow         = '#AA8800',
    bright_cyan    = '#33AAAA',
    bright_white   = '#000000',

    green          = '#228B22',
    blue           = '#0000CC',
    magenta        = '#8B008B',
    red            = '#CC0000',
    amber          = '#CC7700',
    bright_blue    = '#0066CC',

    diag_error     = '#CC0000',
    diag_warn      = '#CC7700',
    diag_info      = '#0066CC',
    diag_hint      = '#008866',

    diff_add       = '#228B22',
    diff_change    = '#CC7700',
    diff_del       = '#CC0000',

    notify_info    = '#0066CC',
    notify_warn    = '#CC7700',
    notify_error   = '#CC0000',
    notify_debug   = '#8B008B',

    border_gray    = '#666666',
    panel_bg       = '#D0D0D0',
    panel_title_fg = '#000000',

    status_bg      = '#E8E8E8',
    status_fg      = '#000000',
    status_dim     = '#666666',
    ai_purple      = '#8B008B',
}

-- ── Highlight Definitions ───────────────────────────────────────

function TurboVisionTheme:_palette()
    return self._variant == 'light' and LIGHT or DARK
end

function TurboVisionTheme:_apply_highlights(ctx)
    local p = self:_palette()

    -- ── Menu bar (top strip) ──
    ctx:highlight('IDEMenuBar',           { bg = p.navy, fg = p.light_gray })
    ctx:highlight('IDEMenuNormal',        { bg = p.navy, fg = p.light_gray })
    ctx:highlight('IDEMenuActive',        { bg = p.bright_cyan, fg = p.white, bold = true })
    ctx:highlight('IDEMenuHotkey',        { bg = p.navy, fg = p.yellow, bold = true })
    ctx:highlight('IDEMenuHover',         { bg = p.bright_cyan, fg = p.white })

    -- ── Menu dropdowns ──
    ctx:highlight('IDEMenuDropdownNormal', { bg = p.cyan, fg = '#1a1a1a' })
    ctx:highlight('IDEMenuDropdownBorder', { bg = p.cyan, fg = p.cyan })
    ctx:highlight('IDEMenuItemNormal',    { bg = p.cyan, fg = p.black })
    ctx:highlight('IDEMenuItemSelected',  { bg = p.navy, fg = p.white, bold = true })
    ctx:highlight('IDEMenuItemDisabled',  { bg = p.cyan, fg = '#888888', italic = true })
    ctx:highlight('IDEMenuShortcut',      { bg = p.cyan, fg = p.navy })
    ctx:highlight('IDEMenuSeparator',     { bg = p.cyan, fg = p.navy })
    ctx:highlight('IDEMenuIcon',          { bg = p.cyan, fg = p.navy })
    ctx:highlight('IDEMenuShadow',        { bg = p.black, fg = p.dark_gray })

    -- ── Buffer tabs in menu bar ──
    ctx:highlight('IDEMenuTabActive',     { bg = p.bright_cyan, fg = p.white, bold = true })
    ctx:highlight('IDEMenuTabInactive',   { bg = p.navy, fg = '#999999' })

    -- ── Status bar (bottom) ──
    -- Mode indicators
    ctx:highlight('IDEModeNormal',   { fg = p.white,  bg = p.blue,    bold = true })
    ctx:highlight('IDEModeInsert',   { fg = p.white,  bg = p.green,   bold = true })
    ctx:highlight('IDEModeVisual',   { fg = p.white,  bg = p.magenta, bold = true })
    ctx:highlight('IDEModeReplace',  { fg = p.white,  bg = p.red,     bold = true })
    ctx:highlight('IDEModeCommand',  { fg = p.black,  bg = p.amber,   bold = true })
    ctx:highlight('IDEModeTerminal', { fg = p.white,  bg = p.bright_blue, bold = true })

    -- Status bar sections
    ctx:highlight('IDEStatusFile',       { fg = p.bright_white, bg = p.status_bg })
    ctx:highlight('IDEStatusGit',        { fg = p.navy, bg = p.status_bg })
    ctx:highlight('IDEStatusPos',        { fg = p.status_dim, bg = p.status_bg })
    ctx:highlight('IDEStatusTool',       { fg = p.status_dim, bg = p.status_bg })
    ctx:highlight('IDEStatusAI',         { fg = p.ai_purple, bg = p.status_bg })
    ctx:highlight('IDEStatusDebug',      { fg = p.red, bg = p.status_bg, bold = true })

    -- Diagnostics in status bar
    ctx:highlight('IDEStatusDiagE',      { fg = p.diag_error, bg = p.status_bg })
    ctx:highlight('IDEStatusDiagW',      { fg = p.diag_warn,  bg = p.status_bg })
    ctx:highlight('IDEStatusDiagI',      { fg = p.diag_info,  bg = p.status_bg })
    ctx:highlight('IDEStatusDiagH',      { fg = p.diag_hint,  bg = p.status_bg })

    -- Git diff in status bar
    ctx:highlight('IDEStatusDiffAdd',    { fg = p.diff_add,    bg = p.status_bg })
    ctx:highlight('IDEStatusDiffChange', { fg = p.diff_change, bg = p.status_bg })
    ctx:highlight('IDEStatusDiffDel',    { fg = p.diff_del,    bg = p.status_bg })

    -- ── Tab bar / Win bar ──
    ctx:highlight('IDETabActive',    { fg = p.white, bg = p.bright_cyan, bold = true })
    ctx:highlight('IDETabInactive',  { fg = p.dark_gray, bg = p.navy })
    ctx:highlight('IDEWinbarPath',   { fg = p.light_gray })
    ctx:highlight('IDEWinbarScope',  { fg = p.dark_gray })

    -- ── Window chrome (TurboVision MDI) ──
    ctx:highlight('IDEWinBorder',    { fg = p.light_gray })
    ctx:highlight('IDEWinBorderNC',  { fg = p.dark_gray })
    ctx:highlight('IDEWinTitle',     { fg = p.white, bold = true })
    ctx:highlight('IDEWinTitleNC',   { fg = p.dark_gray })
    ctx:highlight('IDEWinButton',    { fg = p.yellow })
    ctx:highlight('IDEWinButtonNC',  { fg = p.dark_gray })
    ctx:highlight('IDEWinNumber',    { fg = p.yellow, bold = true })
    ctx:highlight('IDEWinNumberNC',  { fg = p.dark_gray })
    ctx:highlight('IDEWinPos',       { fg = p.yellow })
    ctx:highlight('IDEWinPosNC',     { fg = p.dark_gray })
    ctx:highlight('IDEScrollTrack',  { fg = p.dark_gray })
    ctx:highlight('IDEScrollThumb',  { fg = p.bright_cyan })
    ctx:highlight('IDEScrollButton', { fg = p.light_gray })
    ctx:highlight('WinBar',          { bg = p.cyan, fg = p.black })
    ctx:highlight('WinBarNC',        { bg = p.gray, fg = p.dark_gray })
    ctx:highlight('WinSeparator',    { fg = p.light_gray })

    -- ── Panels / dialogs ──
    ctx:highlight('IDEPanelNormal',   { bg = p.panel_bg, fg = '#E0E0E0' })
    ctx:highlight('IDEPanelBorder',   { bg = p.panel_bg, fg = p.border_gray })
    ctx:highlight('IDEPanelTitle',    { bg = p.panel_bg, fg = p.panel_title_fg, bold = true })
    ctx:highlight('IDEPanelSelected', { bg = p.cyan, fg = p.white, bold = true })
    ctx:highlight('IDEPanelDim',      { bg = p.panel_bg, fg = '#999999' })
    ctx:highlight('IDEPanelAccent',   { bg = p.panel_bg, fg = p.yellow })
    ctx:highlight('IDEPanelIcon',     { bg = p.panel_bg, fg = p.bright_cyan })
    ctx:highlight('IDEPanelCounter',  { bg = p.panel_bg, fg = p.dark_gray })
    ctx:highlight('IDEPanelHiddenCursor', { bg = p.panel_bg, fg = p.panel_bg, blend = 100 })
    ctx:highlight('IDEPanelSearch',  { bg = p.cyan, fg = p.black })
    ctx:highlight('IDEPanelPrompt', { bg = p.panel_bg, fg = p.yellow, bold = true })

    -- Menu selection (used by ContextMenu, ToggleMenu)
    ctx:highlight('IDEMenuSelected', { bg = p.navy, fg = p.white, bold = true })
    ctx:highlight('IDEMenuBorder',   { fg = p.border_gray, bg = p.panel_bg })

    -- ── Dialog widgets (TurboVision) ──
    ctx:highlight('IDEDialogNormal',        { bg = p.gray, fg = p.black })
    ctx:highlight('IDEDialogBorder',        { bg = p.gray, fg = p.white })
    ctx:highlight('IDEDialogTitle',         { bg = p.gray, fg = p.white, bold = true })
    ctx:highlight('IDEDialogShadow',        { bg = p.black })
    ctx:highlight('IDEDialogHotkey',        { bg = p.gray, fg = p.yellow, bold = true })
    ctx:highlight('IDEDialogFocused',       { bg = p.navy, fg = p.white, bold = true })
    ctx:highlight('IDEDialogCheckbox',      { bg = p.gray, fg = p.bright_white })
    ctx:highlight('IDEDialogCheckMark',     { bg = p.gray, fg = p.yellow, bold = true })
    ctx:highlight('IDEDialogRadio',         { bg = p.gray, fg = p.bright_white })
    ctx:highlight('IDEDialogButton',        { bg = p.cyan, fg = p.black })
    ctx:highlight('IDEDialogButtonPrimary', { bg = p.navy, fg = p.white, bold = true })
    ctx:highlight('IDEDialogButtonFocused', { bg = p.navy, fg = p.yellow, bold = true })
    ctx:highlight('IDEDialogListSelected',  { bg = p.navy, fg = p.white, bold = true })
    ctx:highlight('IDEDialogListDisabled',  { bg = p.gray, fg = p.dark_gray, italic = true })

    -- ── Notifications / toasts ──
    ctx:highlight('IDENotifyInfo',        { fg = p.notify_info,  bold = true })
    ctx:highlight('IDENotifyWarn',        { fg = p.notify_warn,  bold = true })
    ctx:highlight('IDENotifyError',       { fg = p.notify_error, bold = true })
    ctx:highlight('IDENotifyDebug',       { fg = p.notify_debug, bold = true })
    ctx:highlight('IDENotifyInfoBorder',  { fg = p.notify_info })
    ctx:highlight('IDENotifyWarnBorder',  { fg = p.notify_warn })
    ctx:highlight('IDENotifyErrorBorder', { fg = p.notify_error })
    ctx:highlight('IDENotifyDebugBorder', { fg = p.notify_debug })
    ctx:highlight('IDENotifyBody',        { fg = p.light_gray })
    ctx:highlight('IDENotifyTitle',       { fg = p.bright_white, bold = true })
    ctx:highlight('IDENotifyTimestamp',   { fg = p.dark_gray })

    -- ── Desktop ──
    local editor_bg = IDE.theme:bg('Normal') or '#222436'
    ctx:highlight('IDEDesktop', { fg = p.dark_gray, bg = editor_bg })
    ctx:highlight('IDEDesktopLogo', { fg = p.bright_cyan, bg = editor_bg, bold = true })
    ctx:highlight('IDEDesktopVersion', { fg = p.blue, bg = editor_bg })
    ctx:highlight('IDEDesktopSection', { fg = p.yellow, bg = editor_bg })
    ctx:highlight('IDEDesktopFile', { fg = p.light_gray, bg = editor_bg })
    ctx:highlight('IDEDesktopKey', { fg = p.bright_cyan, bg = editor_bg })
    ctx:highlight('IDEDesktopHint', { fg = p.dark_gray, bg = editor_bg, italic = true })

    -- ── F-key bar ──
    ctx:highlight('IDEFKeyNumber',  { fg = p.white, bg = p.black, bold = true })
    ctx:highlight('IDEFKeyLabel',   { fg = p.black, bg = p.light_gray })
    ctx:highlight('IDEFKeySep',     { fg = p.dark_gray, bg = p.light_gray })

    -- ── StatusLine background fill ──
    -- Override Neovim's default StatusLine/StatusLineNC so the entire bar
    -- gets the classic light-gray background instead of the colorscheme default.
    ctx:highlight('StatusLine',   { bg = p.status_bg, fg = p.status_fg })
    ctx:highlight('StatusLineNC', { bg = p.status_bg, fg = p.status_dim })
end

-- ── Registration ────────────────────────────────────────────────

function TurboVisionTheme:on_register(ctx)
    -- Read persisted variant from a global setting if available
    local saved = IDE.config:get('ide_turbovision_variant', 'dark')
    if saved == 'light' or saved == 'dark' then
        self._variant = saved
    end

    -- Apply all highlight overrides
    self:_apply_highlights(ctx)

    -- Re-apply when colorscheme changes (themes like tokyonight re-define
    -- highlight groups on ColorScheme, so we must override again)
    ctx:hook('ColorScheme', function()
        -- Use a short defer so the base theme finishes applying first
        vim.defer_fn(function()
            if self:is_enabled() then
                self:_apply_highlights(self._ctx)
            end
        end, 10)
    end, { desc = 'TurboVisionTheme: re-apply after colorscheme change' })

    -- Toggle command: switch between dark and light
    ctx:command('IDETurboVision', function(opts)
        local arg = opts.fargs and opts.fargs[1] or nil
        if arg == 'dark' or arg == 'light' then
            self._variant = arg
        elseif arg == 'toggle' or arg == nil then
            self._variant = self._variant == 'dark' and 'light' or 'dark'
        else
            ctx:notify('Usage: IDETurboVision [dark|light|toggle]', 'warn')
            return
        end
        IDE.config:set('ide_turbovision_variant', self._variant)
        self:_apply_highlights(self._ctx)
        IDE.ui:refresh_status()
        IDE.ui:redraw_tabline()
        ctx:notify('TurboVision: ' .. self._variant .. ' palette applied')
    end, { desc = 'Switch TurboVision palette (dark/light/toggle)', nargs = '?' })

    -- Register a config toggle
    ctx:toggle('turbovision_theme', {
        desc = 'TurboVision IDE chrome theme',
        default = true,
        on_toggle = function(enabled)
            if enabled then
                self:_apply_highlights(self._ctx)
            end
            -- When disabled, a colorscheme reload will restore defaults
        end,
    })
end

--- Get the current variant.
---@return string # 'dark' or 'light'
function TurboVisionTheme:variant()
    return self._variant
end

--- Set the variant and re-apply.
---@param v string # 'dark' or 'light'
function TurboVisionTheme:set_variant(v)
    if v ~= 'dark' and v ~= 'light' then return end
    self._variant = v
    if self:is_enabled() and self._ctx then
        self:_apply_highlights(self._ctx)
    end
end

function TurboVisionTheme:__tostring()
    return string.format('TurboVisionTheme(%s, %s)', self._variant, self._enabled and 'enabled' or 'disabled')
end

return TurboVisionTheme

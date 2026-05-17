-- Statusline Extension: owned statusbar, tabbar, and winbar.
-- Replaces lualine by populating the toolkit StatusBar/TabBar/WinBar classes
-- and rendering them natively via vim.o.statusline/tabline/winbar.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local StatusBar = require 'ide.toolkit.StatusBar'
local TabBar = require 'ide.toolkit.TabBar'
local WinBar = require 'ide.toolkit.WinBar'
local Timer = require 'ide.Timer'

local Statusline = Class('Statusline', Extension)

function Statusline:init()
    Extension.init(self, 'Statusline')
end

local MODE_MAP = {
    ['n']     = { text = ' Ready',    hl = 'IDEModeNormal' },
    ['no']    = { text = ' Ready',    hl = 'IDEModeNormal' },
    ['nov']   = { text = ' Ready',    hl = 'IDEModeNormal' },
    ['noV']   = { text = ' Ready',    hl = 'IDEModeNormal' },
    ['i']     = { text = '󰏫 Editing',  hl = 'IDEModeInsert' },
    ['ic']    = { text = '󰏫 Editing',  hl = 'IDEModeInsert' },
    ['v']     = { text = '󰒅 Select',   hl = 'IDEModeVisual' },
    ['V']     = { text = '󰒅 Select',   hl = 'IDEModeVisual' },
    ['\22']   = { text = '󰒅 Select',   hl = 'IDEModeVisual' },
    ['s']     = { text = '󰒅 Select',   hl = 'IDEModeVisual' },
    ['S']     = { text = '󰒅 Select',   hl = 'IDEModeVisual' },
    ['R']     = { text = '󰛔 Replace',  hl = 'IDEModeReplace' },
    ['Rv']    = { text = '󰛔 Replace',  hl = 'IDEModeReplace' },
    ['c']     = { text = ' Command', hl = 'IDEModeCommand' },
    ['cv']    = { text = ' Command', hl = 'IDEModeCommand' },
    ['t']     = { text = ' Terminal', hl = 'IDEModeTerminal' },
    ['nt']    = { text = ' Terminal', hl = 'IDEModeTerminal' },
}

-- LSP progress tracking state
local lsp_progress = {}    ---@type table<any, { client: string, title: string, message: string, percentage: integer|nil }>
local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local spinner_idx = 0
local spinner_timer = nil  ---@type Timer|nil

function Statusline:_define_highlights()
    IDE.theme:define('IDEModeNormal',  { fg = '#1a1b26', bg = '#7aa2f7', bold = true, default = true })
    IDE.theme:define('IDEModeInsert',  { fg = '#1a1b26', bg = '#9ece6a', bold = true, default = true })
    IDE.theme:define('IDEModeVisual',  { fg = '#1a1b26', bg = '#bb9af7', bold = true, default = true })
    IDE.theme:define('IDEModeReplace', { fg = '#1a1b26', bg = '#f7768e', bold = true, default = true })
    IDE.theme:define('IDEModeCommand', { fg = '#1a1b26', bg = '#e0af68', bold = true, default = true })
    IDE.theme:define('IDEModeTerminal',{ fg = '#1a1b26', bg = '#7dcfff', bold = true, default = true })
    IDE.theme:define('IDEStatusFile',  { fg = '#c0caf5', default = true })
    IDE.theme:define('IDEStatusGit',   { fg = '#7aa2f7', default = true })
    IDE.theme:define('IDEStatusDiagE', { fg = '#f7768e', default = true })
    IDE.theme:define('IDEStatusDiagW', { fg = '#e0af68', default = true })
    IDE.theme:define('IDEStatusDiagI', { fg = '#0db9d7', default = true })
    IDE.theme:define('IDEStatusDiagH', { fg = '#1abc9c', default = true })
    IDE.theme:define('IDEStatusPos',   { fg = '#565f89', default = true })
    IDE.theme:define('IDEStatusDebug', { fg = '#f7768e', bold = true, default = true })
    IDE.theme:define('IDEStatusDiffAdd', { fg = '#9ece6a', default = true })
    IDE.theme:define('IDEStatusDiffChange', { fg = '#e0af68', default = true })
    IDE.theme:define('IDEStatusDiffDel', { fg = '#f7768e', default = true })
    IDE.theme:define('IDEStatusTool',  { fg = '#737aa2', default = true })
    IDE.theme:define('IDEStatusAI',    { fg = '#bb9af7', default = true })
    IDE.theme:define('IDEStatusLspProgress', { fg = '#7dcfff', default = true })
    IDE.theme:define('IDEFKeyNumber',  { fg = '#1a1b26', bg = '#c0caf5', bold = true, default = true })
    IDE.theme:define('IDEFKeyLabel',   { fg = '#c0caf5', bg = '#1a1b26', default = true })
    IDE.theme:define('IDEFKeySep',     { fg = '#3b4261', bg = '#1a1b26', default = true })
    IDE.theme:define('IDETabActive',   { fg = '#c0caf5', bg = '#3b4261', bold = true, default = true })
    IDE.theme:define('IDETabInactive', { fg = '#565f89', default = true })
    IDE.theme:define('IDEWinbarPath',  { fg = '#565f89', default = true })
    IDE.theme:define('IDEWinbarScope', { fg = '#737aa2', default = true })
    IDE.theme:define('IDEMenuSelected', { bg = '#3b4261', bold = true, default = true })
    IDE.theme:define('IDEMenuNormal', { fg = '#c0caf5', bg = '#1a1b26', default = true })
    IDE.theme:define('IDEMenuBorder', { fg = '#3b4261', bg = '#1a1b26', default = true })
    IDE.theme:define('IDEMacroRecording', { fg = '#1a1b26', bg = '#f7768e', bold = true, default = true })
    IDE.theme:link('NormalMenuItem', 'Special')
    IDE.theme:link('SpecialMenuItem', 'Boolean')
end

function Statusline:_build_statusbar()
    local bar = StatusBar()

    bar:left('macro', function()
        local reg = vim.fn.reg_recording()
        if reg == '' then return '', nil end
        return ' REC @' .. reg .. ' ', 'IDEMacroRecording'
    end)

    bar:left('mode', function()
        local mode = IDE.ui:mode().mode
        local cfg = MODE_MAP[mode] or MODE_MAP['n']
        return ' ' .. cfg.text .. ' ', cfg.hl
    end)

    bar:left('git_branch', function()
        local branch = IDE.git:branch()
        if branch and branch ~= '' then
            return ' ' .. branch, 'IDEStatusGit'
        end
        return '', nil
    end, { on_click = function()
        IDE.commands:execute('IDEGit')
    end })

    bar:left('filename', function()
        local buf = Buffer.current()
        if not buf:is_valid() then return '', nil end
        local name = buf:name() or '[No Name]'
        local modified = buf:is_modified() and ' [+]' or ''
        return ' ' .. name .. modified, 'IDEStatusFile'
    end)

    bar:left('search_count', function()
        if vim.v.hlsearch == 0 then return '', nil end
        local ok, result = pcall(vim.fn.searchcount, { maxcount = 999 })
        if ok and result and result.total and result.total > 0 then
            return string.format(' [%d/%d]', result.current, result.total), 'IDEStatusPos'
        end
        return '', nil
    end)

    bar:left('diff', function()
        local buf = Buffer.current()
        if not buf:is_valid() then return '', nil end
        local diff = buf:git():diff_summary()
        local parts = {}
        if diff.added > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiffAdd#+%d', diff.added) end
        if diff.changed > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiffChange#~%d', diff.changed) end
        if diff.removed > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiffDel#-%d', diff.removed) end
        if #parts > 0 then return table.concat(parts, ' ') .. '%*', nil end
        return '', nil
    end)

    bar:left('lsp_progress', function()
        if vim.tbl_isempty(lsp_progress) then return '', nil end
        local frame = spinner_frames[spinner_idx + 1]
        local items = {}
        for _, p in pairs(lsp_progress) do
            local msg = p.title
            if p.percentage then
                msg = msg .. ' ' .. p.percentage .. '%%'
            end
            items[#items + 1] = p.client .. ': ' .. msg
        end
        return frame .. ' ' .. table.concat(items, ', '), 'IDEStatusLspProgress'
    end)

    bar:right('debugger', function()
        local ok, dap = pcall(require, 'dap')
        if ok and dap.status() ~= '' then
            return ' ' .. dap.status(), 'IDEStatusDebug'
        end
        return '', nil
    end, { cond = function()
        local ok, dap = pcall(require, 'dap')
        return ok and dap.status() ~= ''
    end })

    bar:right('diagnostics', function()
        local buf = Buffer.current()
        if not buf:is_valid() then return '', nil end
        local DS = require 'ide.DiagnosticSet'
        local e = buf:diagnostics():count(DS.ERROR)
        local w = buf:diagnostics():count(DS.WARN)
        local i = buf:diagnostics():count(DS.INFO)
        local h = buf:diagnostics():count(DS.HINT)
        local parts = {}
        if e > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiagE# %d', e) end
        if w > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiagW# %d', w) end
        if i > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiagI#󰋼 %d', i) end
        if h > 0 then parts[#parts + 1] = string.format('%%#IDEStatusDiagH#󰌵 %d', h) end
        if #parts > 0 then return table.concat(parts, ' ') .. '%*', nil end
        return '', nil
    end, { on_click = function()
        pcall(function() IDE.ui.finder:diagnostics() end)
    end })

    bar:right('ai', function()
        local ok, api = pcall(require, 'supermaven-nvim.api')
        if ok and api.is_running() then
            return '󱐏 AI', 'IDEStatusAI'
        end
        return '', nil
    end, { cond = function()
        local ok, api = pcall(require, 'supermaven-nvim.api')
        return ok and api.is_running()
    end })

    bar:right('lsp', function()
        local buf = Buffer.current()
        if not buf:is_valid() then return '', nil end
        local clients = buf:lsp():clients()
        if #clients == 0 then return '', nil end
        local names = {}
        for _, c in ipairs(clients) do
            if not c:is_stopped() then names[#names + 1] = c.name end
        end
        return table.concat(names, ' '), 'IDEStatusTool'
    end, { on_click = function()
        IDE.commands:execute('IDELsp')
    end })

    bar:right('filetype', function()
        local buf = Buffer.current()
        if not buf:is_valid() then return '', nil end
        local ft = buf:filetype()
        if ft and ft ~= '' then return ft, 'IDEStatusTool' end
        return '', nil
    end)

    bar:right('encoding', function()
        local buf = require('ide.Buffer').current()
        local enc = buf:is_valid() and buf:option('fileencoding') or ''
        enc = enc ~= '' and enc or IDE.config:option('encoding')
        if enc ~= 'utf-8' then return enc, 'IDEStatusTool' end
        return '', nil
    end)

    bar:right('fileformat', function()
        local ff = vim.bo.fileformat
        if ff ~= 'unix' then return '[' .. ff .. ']', 'IDEStatusTool' end
        return '', nil
    end)

    bar:right('treesitter', function()
        local buf = Buffer.current()
        if buf:is_valid() and buf:ast():has_parser() then
            return '', 'IDEStatusTool'
        end
        return '', nil
    end)

    bar:right('processes', function()
        if IDE.progress and IDE.progress:is_busy() then
            local tasks = IDE.progress:active()
            return string.format(' %d', #tasks), 'IDEStatusTool'
        end
        return '', nil
    end)

    bar:right('spell', function()
        if vim.wo.spell then return '󰓆', 'IDEStatusTool' end
        return '', nil
    end)

    bar:right('progress', function()
        local cur = vim.fn.line('.')
        local total = vim.fn.line('$')
        if total <= 1 then return 'Top', 'IDEStatusPos' end
        if cur == 1 then return 'Top', 'IDEStatusPos' end
        if cur == total then return 'Bot', 'IDEStatusPos' end
        return math.floor(cur / total * 100) .. '%%', 'IDEStatusPos'
    end)

    -- F-key hints (TurboVision style, right side) — each clickable
    local fkey_actions = {
        { key = 'F1', label = 'Keys', action = function() IDE.keys:show_hints('<leader>', 'n') end },
        { key = 'F2', label = 'Rename', action = function() IDE.actions:execute('lsp.rename') end },
        { key = 'F3', label = 'Find', action = function() IDE.ui.finder:files() end },
        { key = 'F5', label = 'Debug', action = function() IDE.actions:execute('debug.continue') end },
        { key = 'F6', label = 'Window', action = function() require('ide.Window').cycle() end },
        { key = 'F9', label = 'Break', action = function() IDE.actions:execute('debug.toggleBreakpoint') end },
        { key = 'F10', label = 'Menu', action = function() IDE.menu_bar:open('&File') end },
    }
    for i, fk in ipairs(fkey_actions) do
        local sep = i > 1 and '%#IDEFKeySep#│' or ''
        bar:right('fkey_' .. fk.key, function()
            return sep .. string.format('%%#IDEFKeyNumber#%s%%#IDEFKeyLabel#%s', fk.key, fk.label), nil
        end, { on_click = fk.action })
    end

    return bar
end

function Statusline:_build_tabbar()
    local bar = TabBar()

    bar:left('branch_indicator', function()
        local branch = IDE.git:branch()
        if branch and branch ~= '' then
            return ' ' .. branch, 'IDEStatusGit'
        end
        return '', nil
    end)

    bar:right('buffer_tabs', function()
        local bufs = IDE.buffers:listed()
        local cur = Buffer.current():id()
        local parts = {}
        local StatusBar = require 'ide.toolkit.StatusBar'
        for i, buf in ipairs(bufs) do
            local name = buf:name() or '[No Name]'
            local is_active = buf:id() == cur
            local hl = is_active and 'IDETabActive' or 'IDETabInactive'
            -- File icon
            local icon = ''
            if IDE.icons and IDE.icons:is_loaded() and name ~= '[No Name]' then
                local fname = IDE.fs:basename(name)
                local ext = IDE.fs:extension(name)
                local ic = IDE.icons:for_file(fname, ext)
                if ic then icon = ic:char() .. ' ' end
            end
            -- Modified indicator
            local mod = buf:is_modified() and '● ' or ''
            local tab_id = 'tab_' .. buf:id()
            local label = string.format('%%#%s# %s%s%s%s', hl, mod, icon, name, ' ')
            parts[#parts + 1] = StatusBar.click(tab_id, function()
                if buf:is_valid() then
                    Window.current():set_buffer(buf)
                end
            end, label)
        end
        return table.concat(parts, ''), nil
    end)

    return bar
end

function Statusline:_build_winbar()
    local bar = WinBar()

    bar:left('filepath', function()
        local buf = Buffer.current()
        if not buf:is_valid() or not buf:is_normal() then return '', nil end
        local path = buf:path()
        if not path then return '', nil end
        local root = IDE.git:root() or IDE.fs:cwd()
        return IDE.fs:relative_path(root, path, { include_base_dir = true }) or path, 'IDEWinbarPath'
    end)

    bar:right('breadcrumb', function()
        local scope = Buffer.current():ast():breadcrumb()
        if scope and scope ~= '' then
            return scope, 'IDEWinbarScope'
        end
        return '', nil
    end)

    return bar
end

function Statusline:on_register(ctx)
    self:_define_highlights()

    IDE.statusbar = self:_build_statusbar()
    IDE.tabbar = self:_build_tabbar()
    IDE.winbar = self:_build_winbar()

    -- StatusBar is built but not applied as native — FramedWindow's footer
    -- handles the bottom border. The StatusBar content is available via
    -- IDE.statusbar:render() for any component that wants to use it.

    local Dispatch = require 'ide.Dispatch'
    Dispatch.renderer('tabbar', function() return IDE.tabbar:render() end)
    IDE.config:set_option('showtabline', 2)
    IDE.config:set_option('tabline', '%!v:lua.IDE_render_tabbar()')

    -- Winbar disabled — FramedWindow title bar replaces it

    local refresh = Timer.debounce(50, function()
        IDE.ui:refresh_status()
    end)

    -- LSP progress tracking
    ctx:hook('LspProgress', function(ev)
        local data = ev.data
        if not data or not data.params then return end
        local token = data.params.token
        local value = data.params.value
        if not value then return end

        local client = IDE.lsp:client_by_id(data.client_id)
        local name = client and client.name or 'LSP'

        if value.kind == 'begin' then
            lsp_progress[token] = {
                client = name,
                title = value.title or '',
                message = value.message or '',
            }
        elseif value.kind == 'report' then
            if lsp_progress[token] then
                lsp_progress[token].message = value.message or lsp_progress[token].message
                if value.percentage then
                    lsp_progress[token].percentage = value.percentage
                end
            end
        elseif value.kind == 'end' then
            lsp_progress[token] = nil
        end

        -- Start spinner animation when progress begins, stop when all done
        if not vim.tbl_isempty(lsp_progress) then
            if not spinner_timer or not spinner_timer:is_active() then
                spinner_timer = Timer.interval(80, function()
                    spinner_idx = (spinner_idx + 1) % #spinner_frames
                    IDE.ui:refresh_status()
                end, 'lsp-progress-spinner')
            end
        else
            if spinner_timer and spinner_timer:is_active() then
                spinner_timer:stop()
                spinner_timer = nil
            end
            spinner_idx = 0
        end

        refresh()
    end, { desc = 'Statusline: track LSP progress' })

    ctx:hook({ 'ModeChanged', 'BufEnter', 'BufWritePost', 'DiagnosticChanged', 'LspAttach', 'LspDetach', 'RecordingEnter', 'RecordingLeave' }, function()
        refresh()
    end, { desc = 'Statusline: refresh on events' })

    ctx:notify('Statusline active')
end

return Statusline

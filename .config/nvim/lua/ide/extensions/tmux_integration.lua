-- Tmux integration extension: seamless window/pane navigation, session management,
-- terminal title sync, and clipboard integration.
-- Replaces the legacy lua/tmux.lua module.

local Extension = require 'ide.Extension'
local Window = require 'ide.Window'
local Buffer = require 'ide.Buffer'

local TmuxIntegration = Class('TmuxIntegration', Extension)

function TmuxIntegration:init()
    Extension.init(self, 'TmuxIntegration')
    self._tmux_had_control = true
end

--- Get the tmux socket path, or nil if not in tmux.
---@return string|nil
function TmuxIntegration:socket()
    local tmux = vim.env.TMUX
    if tmux then
        return tmux:match('^([^,]+)')
    end
end

--- Whether we are running inside a tmux session.
---@return boolean
function TmuxIntegration:in_tmux()
    return self:socket() ~= nil
end

--- Run a tmux command via the IDE shell and return stdout.
---@param args string[]
---@return string|nil
function TmuxIntegration:_tmux_run(args)
    local socket = self:socket()
    if not socket then return nil end

    local full_args = { '-S', socket }
    for _, a in ipairs(args) do
        full_args[#full_args + 1] = a
    end

    local result = IDE.shell:run_sync('tmux', full_args)
    return result.code == 0 and result.stdout or nil
end

--- Run a tmux command asynchronously (fire-and-forget or with callback).
---@param args string[]
---@param callback? fun(stdout: string)
function TmuxIntegration:_tmux_run_async(args, callback)
    local socket = self:socket()
    if not socket then return end

    local full_args = { '-S', socket }
    for _, a in ipairs(args) do
        full_args[#full_args + 1] = a
    end

    IDE.shell:run('tmux', full_args, nil, function(result)
        if callback and result.code == 0 then
            callback(result.stdout)
        end
    end)
end

--- Get the current tmux pane ID and zoom state.
---@return string|nil pane_id
---@return boolean zoomed
function TmuxIntegration:_current_pane()
    local pane = self:_tmux_run({ 'display-message', '-p', '#{window_zoomed_flag},#D' })
    if pane and pane ~= '' then
        local clean = pane:gsub('\n', '')
        local zoomed, id = clean:match('^([^,]+),(.+)$')
        return id, zoomed == '1'
    end
    return nil, false
end

local TMUX_DIRS = { h = 'L', j = 'D', k = 'U', l = 'R', p = 'l' }

--- Try to change the tmux pane in the given direction.
---@param direction string
---@return boolean
function TmuxIntegration:_change_pane(direction)
    local id, zoomed = self:_current_pane()
    if not id or zoomed then return false end
    self:_tmux_run({ 'select-pane', '-' .. TMUX_DIRS[direction] })
    local new_id = self:_current_pane()
    return new_id ~= id
end

--- Try to change the neovim window in the given direction.
---@param direction string
---@return boolean
function TmuxIntegration:_change_win(direction)
    local cur = Window.current():id()
    pcall(vim.cmd.wincmd, direction)
    return cur ~= Window.current():id()
end

--- Navigate to window/pane in the given direction.
---@param direction string # 'h', 'j', 'k', 'l', or 'p'
function TmuxIntegration:navigate(direction)
    if not self:in_tmux() then
        self:_change_win(direction)
        return
    end
    if direction == 'p' then
        if self._tmux_had_control then self:_change_pane(direction) else self:_change_win(direction) end
        return
    end
    local win_changed = self:_change_win(direction)
    if win_changed then
        self._tmux_had_control = false
    else
        self._tmux_had_control = self:_change_pane(direction)
    end
end

-- ── Project directory discovery ──────────────────────────────────────

--- Get the project root directory, falling back to cwd.
--- Used when creating new tmux sessions to set the working directory.
---@return string
function TmuxIntegration:_project_dir()
    local proj = IDE:project()
    if proj then
        return proj:root()
    end
    return IDE.fs:cwd()
end

-- ── Session management ───────────────────────────────────────────────

--- Manage tmux sessions — list, create, switch.
function TmuxIntegration:manage_sessions()
    if not self:in_tmux() then
        IDE.ui:warn('Not inside a tmux session')
        return
    end

    -- Gather session data
    local out = self:_tmux_run({
        'list-sessions', '-F', '#{session_name}:#{pane_current_path}:#{session_attached}',
    })
    if not out then
        IDE.ui:warn('Failed to list tmux sessions')
        return
    end
    local current_out = self:_tmux_run({ 'display-message', '-p', '-F', '#{session_name}' })
    local current_name = current_out and current_out:gsub('\n', '') or ''

    local items = {}
    for line in out:gmatch('[^\n]+') do
        local name, cwd, attached = line:match('^(.-):(.-):(.+)$')
        if name then
            items[#items + 1] = {
                name = name,
                cwd = cwd,
                attached = attached == '1',
                current = name == current_name,
            }
        end
    end

    -- Build display list — new sessions use project root as the working directory
    local project_dir = self:_project_dir()
    local display_items = { ' <new session>' }
    local display_data = { { new = true, dir = project_dir } }
    for _, s in ipairs(items) do
        local tag = s.current and ' [current]' or s.attached and ' [attached]' or ''
        local dir = IDE.fs:shorten(s.cwd or '')
        display_items[#display_items + 1] = string.format('%s%s  %s', s.name, tag, dir)
        display_data[#display_data + 1] = s
    end

    vim.ui.select(display_items, { prompt = 'Tmux Sessions' }, function(_, idx)
        if not idx then return end
        local picked = display_data[idx]
        if picked.new then
            vim.ui.input({ prompt = 'Session name: ' }, function(name)
                if not name or name == '' then return end
                name = name:gsub('%.', '_')
                self:_tmux_run({ 'new', '-d', '-s', name, '-c', project_dir })
                self:_tmux_run({ 'switch', '-t', name })
                IDE.ui:info('Switched to session ' .. name)
            end)
        elseif picked.current then
            IDE.ui:info('Already in session ' .. picked.name)
        else
            self:_tmux_run({ 'switch', '-t', picked.name })
            IDE.ui:info('Switched to session ' .. picked.name)
        end
    end)
end

-- ── Terminal title sync ──────────────────────────────────────────────

--- Update the tmux window title to reflect the current project and file.
function TmuxIntegration:_update_title()
    if not self:in_tmux() then return end

    local proj = IDE:project()
    local project_name = proj and proj:name() or ''
    local buf = Buffer.current()
    local file_name = buf and buf:name() or ''

    local title
    if project_name ~= '' and file_name ~= '' then
        title = project_name .. ' - ' .. file_name
    elseif project_name ~= '' then
        title = project_name
    elseif file_name ~= '' then
        title = file_name
    else
        title = 'nvim'
    end

    self:_tmux_run_async({ 'rename-window', title })
end

-- ── Clipboard integration ────────────────────────────────────────────

--- Set up tmux clipboard integration.
--- When running in tmux and OSC 52 is not available, use tmux's paste buffer
--- for clipboard synchronization.
function TmuxIntegration:_setup_clipboard()
    if not self:in_tmux() then return end

    -- Check if OSC 52 is already handling clipboard (nvim 0.10+)
    -- If the terminal supports OSC 52, let nvim handle it natively.
    if vim.g.clipboard ~= nil then return end

    -- Only override when the system clipboard is not accessible
    -- (e.g. SSH into a tmux session without X11/Wayland forwarding)
    if IDE.shell:has('pbcopy') or IDE.shell:has('xclip') or IDE.shell:has('xsel') or IDE.shell:has('wl-copy') then
        return
    end

    vim.g.clipboard = {
        name = 'tmux',
        copy = {
            ['+'] = { 'tmux', 'load-buffer', '-' },
            ['*'] = { 'tmux', 'load-buffer', '-' },
        },
        paste = {
            ['+'] = { 'tmux', 'save-buffer', '-' },
            ['*'] = { 'tmux', 'save-buffer', '-' },
        },
        cache_enabled = false,
    }
end

-- ── Extension registration ───────────────────────────────────────────

function TmuxIntegration:on_register(ctx)
    local ext = self

    -- Clipboard integration (must be set up early, before any yank/paste)
    self:_setup_clipboard()

    -- Session management (only inside tmux)
    if self:in_tmux() then
        ctx:keymap('n', '<leader>s', function() ext:manage_sessions() end, { desc = 'Tmux sessions' })
    end

    -- Window/pane navigation — works both in and out of tmux.
    -- Alt+Arrow keys move between vim windows; if at the edge, move to tmux pane.
    ctx:keymap('n', '<M-Tab>', function() ext:navigate('p') end, { desc = 'Switch window/pane' })
    ctx:keymap('n', '<M-Left>', function() ext:navigate('h') end, { desc = 'Left pane' })
    ctx:keymap('n', '<M-Right>', function() ext:navigate('l') end, { desc = 'Right pane' })
    ctx:keymap('n', '<M-Down>', function() ext:navigate('j') end, { desc = 'Pane below' })
    ctx:keymap('n', '<M-Up>', function() ext:navigate('k') end, { desc = 'Pane above' })

    -- Terminal title sync — update tmux window title on buffer/directory change
    if self:in_tmux() then
        ctx:hook({ 'BufEnter', 'DirChanged' }, function()
            ext:_update_title()
        end, { desc = 'Update tmux window title' })
    end
end

return TmuxIntegration

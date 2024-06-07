local utils = require 'core.utils'
local shell = require 'core.shell'
local select = require 'ui.select'
local icons = require 'ui.icons'

---@class ui.tmux
local M = {}

--- Gets the TMUX socket or nil if not in a TMUX session
---@return string|nil # the TMUX socket or nil
function M.socket()
    if vim.env.TMUX ~= nil then
        return vim.fn.split(vim.env.TMUX, ',')[1]
    end
end

--- Finds all git enabled directories in a given root
---@param root string # the root to search in
---@param collected string[]|nil # the collected directories
---@return string[] # the collected directories
local function find_git_enabled_dirs(root, collected)
    collected = collected or {}

    if vim.fn.isdirectory(utils.join_paths(root, '.git')) == 1 then
        table.insert(collected, root)
    else
        for _, dir in ipairs(vim.fn.readdir(root)) do
            local full = utils.join_paths(root, dir)
            if full and vim.fn.isdirectory(full) == 1 then
                find_git_enabled_dirs(full, collected)
            end
        end
    end

    return collected
end

---@class ui.tmux.SessionItem # The session item
---@field root string # the root directory of the session
---@field cwd string|nil # the current working directory of the session
---@field session string|nil # the session name
---@field attached boolean|nil # whether the session is attached
---@field current boolean|nil # whether the session is the current one

--- Merges the results of the git enabled directories and the sessions
---@param projects_dirs string[] # the git enabled directories
---@param sessions { cwd: string, session: string, attached: boolean }[] # the sessions
---@return table<string, ui.tmux.SessionItem> # the merged results
local function merge_results(projects_dirs, sessions)
    local results = {}

    local projects_adj = vim.env.PROJECTS_ROOT .. '/'
    for _, root in ipairs(projects_dirs) do
        local name = root:sub(#projects_adj + 1)
        results[name] = {
            root = root,
            session = nil,
        }
    end

    for _, session in ipairs(sessions) do
        results[session.session] = vim.tbl_extend('force', results[session.session] or {}, session)
    end

    return results
end

--- Switches to an existing session
---@param session string|nil # the session to switch to
local function switch_to_session(session)
    shell.async_cmd('tmux', { 'switch', '-t', session }, nil, function(_, _)
        utils.info(string.format('Switched to session *%s*', session))
    end)
end

--- Switches to a session
---@param session string|nil # the session to switch to
---@param create boolean # whether to create the session if it doesn't exist
---@param dir string|nil # the directory to switch to
local function create_or_switch_to_session(session, create, dir)
    if create then
        if session == nil then
            session = vim.fn.input 'Session name: '
            if not session or session == '' then
                return
            end
        end

        session = session:gsub('%.', '_')

        local args = { 'new', '-d', '-s', session }
        if dir then
            table.insert(args, '-c')
            table.insert(args, dir)
        end

        shell.async_cmd('tmux', args, nil, function(_, _)
            switch_to_session(session)
        end)
    else
        switch_to_session(session)
    end
end

local new_session_label = '<new session>'

--- Displays the UI to select and manage sessions
---@param items table<string, ui.tmux.SessionItem> # the items to display
local function display(items)
    ---@type string[][]
    local lines = {}

    table.insert(lines, { new_session_label, '', vim.fn.getcwd() })

    for name, data in pairs(items) do
        local status = data.current and 'current' or data.attached and 'attached' or data.session and 'active' or ''
        table.insert(lines, { name, status, utils.format_relative_path(vim.env.PROJECTS_ROOT, data.root or data.cwd) })
    end

    select.advanced(lines, {
        prompt = 'Select a session',
        index_fields = { 2, 1, 3 },
        callback = function(item)
            local name = item[1]
            if name == new_session_label then
                create_or_switch_to_session(nil, true, item[3] --[[@as string]])
                return
            end

            local i = items[item[1]]
            local dir = i.root or i.cwd

            if item[2] == '' then
                create_or_switch_to_session(
                    item[1] ~= new_session_label and item[1] or nil --[[@as string|nil]],
                    true,
                    dir
                )
            else
                create_or_switch_to_session(item[1] --[[@as string]], false, dir)
            end
        end,
        highlighter = function(item)
            if item[2] == 'current' then
                return 'DiagnosticOk'
            elseif item[2] == 'attached' then
                return 'DiagnosticWarn'
            elseif item[2] == 'active' then
                return 'DiagnosticHint'
            elseif item[1] == new_session_label then
                return 'Question'
            else
                return 'Comment'
            end
        end,
        width = 0.6,
    })
end

--- Lists all the sessions
local function manage_sessions()
    local projects_dirs = vim.env.PROJECTS_ROOT and find_git_enabled_dirs(vim.env.PROJECTS_ROOT) or {}

    shell.async_cmd(
        'tmux',
        { 'list-sessions', '-F', '#{session_name}:#{pane_current_path}:#{session_attached}' },
        nil,
        function(sessions)
            shell.async_cmd('tmux', { 'display-message', '-p', '-F', '#{session_name}' }, nil, function(current_session)
                ---@type { cwd: string, session: string }[]
                local results = vim.iter(sessions)
                    :map(
                        ---@param line string
                        function(line)
                            local session_name, cwd, attached = line:match '^(.-):(.-):(.+)$'
                            return {
                                session = session_name,--[[@as string]]
                                cwd = cwd,--[[@as string]]
                                attached = attached == '1',--[[@as boolean]]
                                current = session_name == current_session[1],--[[@as boolean]]
                            }
                        end
                    )
                    :totable()

                local res = merge_results(projects_dirs, results)
                display(res)
            end)
        end
    )
end

---@alias ui.tmux.NavigateDirection 'h'|'j'|'k'|'l'|'p'

---@type table<ui.tmux.NavigateDirection, string>
local directions_tmux_mapping = {
    ['p'] = 'l',
    ['h'] = 'L',
    ['j'] = 'D',
    ['k'] = 'U',
    ['l'] = 'R',
}

--- Sends the tmux command to the server running on the socket
---@param cmd string # the command to send
---@return string|nil # the result of the command or nil if it failed
function M.cmd(cmd)
    local res = vim.fn.system(string.format('tmux -S %s %s', M.socket(), cmd))
    return vim.v.shell_error == 0 and res or nil
end

--- Gets the current pane in tmux
---@return string|nil, boolean # the current pane or nil if it failed
function M.current_pane()
    local pane = M.cmd "display-message -p '#{window_zoomed_flag},#D'"
    if pane and pane ~= '' then
        local zoomed, id = unpack(vim.fn.split(pane:gsub('\n', ''), ','))
        return id, zoomed == '1'
    end

    return nil, false
end

--- Change the current pane according to direction
---@param direction ui.tmux.NavigateDirection # the direction to change to
---@return boolean # true if the pane changed, false otherwise
local function change_pane(direction)
    local tmux_command = assert(directions_tmux_mapping[direction])

    local id, zoomed = M.current_pane()
    if not id or zoomed then
        return false
    end

    M.cmd(string.format('select-pane -%s', tmux_command))
    local new_id = M.current_pane()

    return new_id ~= id
end

--- Changer the current Neovim window according to direction
--- @param direction ui.tmux.NavigateDirection # the direction to change to
---@return boolean # true if the window changed, false otherwise
local function change_win(direction)
    assert(directions_tmux_mapping[direction])

    local current_window = vim.api.nvim_get_current_win()

    local ok = pcall(vim.cmd.wincmd, direction)
    if not ok then
        utils.hint('Cannot navigate to the ' .. direction .. ' window')
    end

    return current_window ~= vim.api.nvim_get_current_win()
end

local tmux_had_control = true

--- Moves to the window or pane in the given direction
---@param direction ui.tmux.NavigateDirection # the direction to move to
---@return boolean # true if the window or pane changed, false otherwise
function M.navigate(direction)
    assert(directions_tmux_mapping[direction])

    if M.socket() == nil then
        return change_win(direction)
    end

    if direction == 'p' then
        return tmux_had_control and change_pane(direction) or change_win(direction)
    else
        local win_changed = change_win(direction)
        if win_changed then
            tmux_had_control = false
            return true
        end

        tmux_had_control = change_pane(direction)
        return tmux_had_control
    end
end

if M.socket() ~= nil then
    vim.keymap.set('n', '<leader>s', manage_sessions, { desc = icons.UI.TMux .. ' Tmux sessions' })
end

-- window navigation
vim.keymap.set('n', '<M-Tab>', function()
    M.navigate 'p'
end, { desc = 'Switch window' })
vim.keymap.set('n', '<M-Left>', function()
    M.navigate 'h'
end, { desc = 'Go to left window' })
vim.keymap.set('n', '<M-Right>', function()
    M.navigate 'l'
end, { desc = 'Go to right window' })
vim.keymap.set('n', '<M-Down>', function()
    M.navigate 'j'
end, { desc = 'Go to window below' })
vim.keymap.set('n', '<M-Up>', function()
    M.navigate 'k'
end, { desc = 'Go to window above' })

return M

local utils = require 'core.utils'
local shell = require 'core.shell'
local select = require 'ui.select'
local icons = require 'ui.icons'

---@class ui.tmux
local M = {}

--- Check if Tmux is active
---@return boolean
function M.active()
    return os.getenv 'TMUX' ~= nil
end

local projects_root = os.getenv 'PROJECTS_ROOT'
local user_home = os.getenv 'HOME'

--- Simplifies a directory name to be more readable
---@param dir string # the directory to simplify
---@return string # the simplified directory
local function simplify_dir_name(dir)
    assert(type(dir) == 'string')

    local projects_adj = projects_root .. '/'
    if dir:find(projects_adj, 1, true) == 1 then
        return icons.TUI.Ellipsis .. '/' .. dir:sub(#projects_adj + 1)
    end

    local home_adj = user_home .. '/'
    if dir:find(home_adj, 1, true) == 1 then
        return '~/' .. dir:sub(#home_adj + 1)
    end

    return dir
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

--- Merges the results of the git enabled directories and the sessions
---@param projects_dirs string[] # the git enabled directories
---@param sessions { cwd: string, session: string, attached: boolean }[] # the sessions
---@return table<string, { root: string, cwd?: string, session: string, attached?: boolean, current?: boolean }> # the merged results
local function merge_results(projects_dirs, sessions)
    local results = {}

    local projects_adj = projects_root .. '/'
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

            session = session:gsub('%.', '_')
        end

        local args = { 'new', '-d', '-s', session }
        if dir then
            table.insert(args, '-c')
            table.insert(args, dir)
        end

        utils.info(vim.inspect(args))

        shell.async_cmd('tmux', args, nil, function(_, _)
            switch_to_session(session)
        end)
    else
        switch_to_session(session)
    end
end

local new_session_label = '<new session>'

--- Displays the UI to select and manage sessions
---@param items table<string, { root: string, cwd?: string, session?: string, attached?: boolean, current?: boolean }> # the items to display
local function display(items)
    ---@type string[][]
    local lines = {}

    table.insert(lines, { new_session_label, '', vim.fn.getcwd() })

    for name, data in pairs(items) do
        local status = data.current and 'current' or data.attached and 'attached' or data.session and 'active' or ''
        table.insert(lines, { name, status, simplify_dir_name(data.root or data.cwd) })
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
                create_or_switch_to_session(item[1] ~= new_session_label and item[1] or nil --[[@as string|nil]], true, dir)
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
    local projects_dirs = projects_root and find_git_enabled_dirs(projects_root) or {}

    shell.async_cmd('tmux', { 'list-sessions', '-F', '#{session_name}:#{pane_current_path}:#{session_attached}' }, nil, function(sessions)
        shell.async_cmd('tmux', { 'display-message', '-p', '-F', '#{session_name}' }, nil, function(current_session)
            ---@type { cwd: string, session: string }[]
            local results = vim.tbl_map(function(line)
                ---@cast line string
                local session_name, cwd, attached = line:match '^(.-):(.-):(.+)$'
                return {
                    session = session_name,--[[@as string]]
                    cwd = cwd,--[[@as string]]
                    attached = attached == '1',--[[@as boolean]]
                    current = session_name == current_session[1],--[[@as boolean]]
                }
            end, sessions)

            local res = merge_results(projects_dirs, results)
            display(res)
        end)
    end)
end

if M.active() then
    vim.keymap.set('n', '<leader>s', manage_sessions, { desc = icons.UI.TMux .. ' Tmux sessions' })
end

return M

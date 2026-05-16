-- SessionManager: session save/restore abstraction.
-- Persists vim session, shada, IDE config, quickfix lists,
-- and per-buffer cursor positions.

local EventEmitter = require 'ide.EventEmitter'

local SessionManager = Class('SessionManager')
Class.include(SessionManager, EventEmitter)

function SessionManager:init()
    self._dir = vim.fs.joinpath(vim.fn.stdpath('data') --[[@as string]], 'sessions')
    self._enabled = #vim.api.nvim_list_uis() > 0 and vim.fn.argc() == 0
    self._current = nil
end

--- Whether session persistence is enabled (has UI and no file args).
---@return boolean
function SessionManager:is_enabled()
    return self._enabled
end

--- Detect the current session name based on git root + branch.
---@return string|nil
function SessionManager:current()
    if not self._enabled then return nil end

    local git_root = vim.trim(vim.fn.system('git rev-parse --show-toplevel'))
    local name = vim.v.shell_error == 0 and git_root or (vim.uv.cwd() or 'default')

    local git_branch = vim.trim(vim.fn.system('git branch --show-current'))
    if vim.v.shell_error == 0 and git_branch ~= '' then
        name = name .. '-' .. git_branch
    end

    return name
end

--- Encode a session name to a safe file path.
---@param name string
---@return string, string, string # session file, shada file, json file
function SessionManager:_files(name)
    local safe = name:gsub('[/\\:]', '_2F')
    local base = vim.fs.joinpath(self._dir, safe)
    return base .. '.vim', base .. '.shada', base .. '.json'
end

--- Export quickfix list items to a serializable format.
--- Converts buffer numbers to file paths for persistence.
---@return table[]
function SessionManager:_export_quickfix()
    local items = vim.fn.getqflist()
    local exported = {}
    for _, item in ipairs(items) do
        local file = ''
        if item.bufnr and item.bufnr > 0 and vim.api.nvim_buf_is_valid(item.bufnr) then
            file = vim.api.nvim_buf_get_name(item.bufnr)
        end
        if file ~= '' then
            exported[#exported + 1] = {
                file = file,
                lnum = item.lnum,
                end_lnum = item.end_lnum,
                col = item.col,
                end_col = item.end_col,
                text = item.text,
                type = item.type,
                nr = item.nr,
            }
        end
    end
    return exported
end

--- Import quickfix list items from saved data.
--- Converts file paths back to buffer numbers, skipping missing files.
---@param items table[]
function SessionManager:_import_quickfix(items)
    if not items or #items == 0 then return end
    local restored = {}
    for _, item in ipairs(items) do
        if item.file and vim.fn.filereadable(item.file) == 1 then
            local bufnr = vim.fn.bufadd(item.file)
            if bufnr > 0 then
                restored[#restored + 1] = {
                    bufnr = bufnr,
                    lnum = item.lnum or 0,
                    end_lnum = item.end_lnum,
                    col = item.col or 0,
                    end_col = item.end_col,
                    text = item.text or '',
                    type = item.type or '',
                    nr = item.nr or 0,
                }
            end
        end
    end
    if #restored > 0 then
        vim.fn.setqflist(restored, 'r')
    end
end

--- Collect cursor positions for all normal buffers with files.
---@return table<string, { row: integer, col: integer }>
function SessionManager:_export_cursors()
    local cursors = {}
    for _, id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(id) and vim.bo[id].buftype == '' then
            local file = vim.api.nvim_buf_get_name(id)
            if file ~= '' then
                local wins = vim.fn.getbufinfo(id)[1].windows
                if wins and #wins > 0 then
                    local ok, pos = pcall(vim.api.nvim_win_get_cursor, wins[1])
                    if ok then
                        cursors[file] = { row = pos[1], col = pos[2] }
                    end
                end
            end
        end
    end
    return cursors
end

--- Restore cursor positions for loaded buffers.
---@param cursors table<string, { row: integer, col: integer }>
function SessionManager:_import_cursors(cursors)
    if not cursors then return end
    for _, id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(id) and vim.bo[id].buftype == '' then
            local file = vim.api.nvim_buf_get_name(id)
            local pos = cursors[file]
            if pos then
                local wins = vim.fn.getbufinfo(id)[1].windows
                if wins and #wins > 0 then
                    local line_count = vim.api.nvim_buf_line_count(id)
                    local row = math.min(pos.row, line_count)
                    pcall(vim.api.nvim_win_set_cursor, wins[1], { row, pos.col })
                end
            end
        end
    end
end

--- Save the current session (vim session + shada + config + quickfix + cursors).
---@param name string|nil # defaults to current() name
function SessionManager:save(name)
    name = name or self:current() or vim.uv.cwd() or 'default'
    vim.fn.mkdir(self._dir, 'p')

    -- Close terminal buffers (can't restore)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end

    local session_file, shada_file, custom_file = self:_files(name)
    pcall(vim.cmd, 'mks! ' .. session_file)
    pcall(vim.cmd, 'wshada! ' .. shada_file)

    -- Save IDE config state, quickfix list, and cursor positions
    local custom = {}
    if IDE and IDE.config then
        custom.config = IDE.config:export()
    end
    custom.quickfix = self:_export_quickfix()
    custom.cursors = self:_export_cursors()

    local ok, json = pcall(vim.json.encode, custom)
    if ok and json then
        IDE.fs:write(custom_file, json)
    end

    self:emit('save', name)
end

--- Restore a saved session (vim session + shada + config + quickfix + cursors).
---@param name string|nil
---@return integer # number of buffers restored
function SessionManager:restore(name)
    name = name or self:current() or vim.uv.cwd() or 'default'
    local session_file, shada_file, custom_file = self:_files(name)

    if not vim.uv.fs_stat(session_file) then return 0 end

    pcall(vim.cmd, 'silent! tabonly!')
    pcall(vim.cmd, 'silent! %bd!')

    if vim.uv.fs_stat(shada_file) then
        pcall(vim.cmd.rshada, shada_file)
    end
    pcall(vim.cmd.source, session_file)

    -- Restore IDE config state, quickfix list, and cursor positions
    if vim.uv.fs_stat(custom_file) then
        local content = IDE.fs:read(custom_file)
        if content then
            local ok, data = pcall(vim.json.decode, content)
            if ok and data then
                if data.config and IDE.config then
                    pcall(function() IDE.config:import(data.config) end)
                end
                if data.quickfix then
                    pcall(function() self:_import_quickfix(data.quickfix) end)
                end
                if data.cursors then
                    -- Defer cursor restore so buffers are fully loaded
                    vim.schedule(function()
                        pcall(function() self:_import_cursors(data.cursors) end)
                    end)
                end
            end
        end
    end

    local buf_count = #vim.tbl_filter(function(id)
        return vim.api.nvim_buf_is_valid(id) and vim.bo[id].buftype == '' and vim.api.nvim_buf_get_name(id) ~= ''
    end, vim.api.nvim_list_bufs())

    pcall(function() IDE.ui:redraw() end)
    self:emit('restore', name, buf_count)
    return buf_count
end

--- Check if a session exists.
---@param name string
---@return boolean
function SessionManager:exists(name)
    local session_file = self:_files(name)
    return vim.uv.fs_stat(session_file) ~= nil
end

--- List saved session names.
---@return string[]
function SessionManager:list()
    local result = {}
    if vim.uv.fs_stat(self._dir) then
        for name, _ in vim.fs.dir(self._dir) do
            if name:match('%.vim$') then
                result[#result + 1] = name:gsub('%.vim$', ''):gsub('_2F', '/')
            end
        end
    end
    return result
end

---@return string
function SessionManager:__tostring()
    return string.format('SessionManager(%d sessions)', #self:list())
end

return SessionManager

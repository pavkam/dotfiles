math.randomseed(os.time())

---@type string
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

--- Generates a new UUID
---@return string # the generated UUID
function vim.fn.uuid()
    ---@param c string
    local function subs(c)
        local v = (((c == 'x') and math.random(0, 15)) or math.random(8, 11))
        return string.format('%x', v)
    end

    local res = uuid_template:gsub('[xy]', subs)
    return res
end

--- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
function vim.fn.timezone_offset(timestamp)
    assert(type(timestamp) == 'number')

    local utc_date = os.date('!*t', timestamp)
    local local_date = os.date('*t', timestamp)

    local_date.isdst = false

    local diff = os.difftime(os.time(local_date --[[@as osdateparam]]), os.time(utc_date --[[@as osdateparam]]))
    local h, m = math.modf(diff / 3600)

    return 100 * h + 60 * m
end

--- Checks if a mode is visual
---@param mode string|nil # the mode to check or the current mode if nil
---@return boolean # true if the mode is visual, false otherwise
function vim.fn.in_visual_mode(mode)
    mode = mode or vim.api.nvim_get_mode().mode

    return mode == 'v' or mode == 'V' or mode == ''
end

--- Gets the selected text from the current buffer in visual mode
---@return string # the selected text
function vim.fn.visual_selected_text()
    assert(vim.fn.in_visual_mode())

    local old = vim.fn.getreg 'a'
    vim.cmd [[silent! normal! "aygv]]

    local original_selection = vim.fn.getreg 'a'
    vim.fn.setreg('a', old)

    local res, _ = original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
    return res
end

--- Confirms an operation that requires the buffer to be saved
---@param buffer integer|nil # the buffer to confirm for or the current buffer if 0 or nil
---@param reason string|nil # the reason for the confirmation
---@return boolean # true if the buffer was saved or false if the operation was cancelled
function vim.fn.confirm_saved(buffer, reason)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if vim.bo[buffer].modified then
        local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
        local choice = vim.fn.confirm(
            string.format(message, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t'), reason),
            '&Yes\n&No\n&Cancel'
        )

        if choice == 0 or choice == 3 then -- Cancel
            return false
        end

        if choice == 1 then -- Yes
            vim.api.nvim_buf_call(buffer, vim.cmd.write)
        end
    end

    return true
end

--- Forget all a file in the oldfiles list
---@param file string|nil # the file to forget or nil to firget all files
function vim.fn.forget_oldfile(file)
    if not file then
        vim.cmd [[
            let v:oldfiles = []
        ]]
        return
    end

    assert(type(file) == 'string' and file ~= '')

    for i, old_file in ipairs(vim.v.oldfiles) do
        if old_file == file then
            vim.cmd('call remove(v:oldfiles, ' .. (i - 1) .. ')')
            break
        end
    end
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode
function vim.fn.create_undo_point()
    assert(vim.api.nvim_get_mode().mode == 'i')

    vim.api.nvim_feedkeys(undo_command, 'n', false)
end

---@alias vim.fn.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target vim.fn.Target # the target to expand
---@return integer, string, boolean # the buffer and the path and whether the buffer corresponds to the path
function vim.fn.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()

        local path = vim.api.nvim_buf_get_name(target)
        if not path or path == '' then
            return target, '', false
        end

        return target, vim.fs.expand_path(path) or path, true
    elseif type(target) == 'string' then
        ---@cast target string
        if target == '' then
            return vim.api.nvim_get_current_buf(), '', false
        end

        local path = vim.fs.expand_path(target) or target

        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local buf_path = vim.api.nvim_buf_get_name(buf)
            if buf_path and buf_path ~= '' and vim.fs.expand_path(buf_path) == path then
                return buf, path, true
            end
        end

        return vim.api.nvim_get_current_buf(), path, false
    else
        error 'Invalid target type'
    end
end

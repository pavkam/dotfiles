--- Forget all a file in the oldfiles list
---@param file string|nil # the file to forget or nil to forget all files
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

--- Creates an undo point if in insert mode.
---@return boolean # true if the undo point was created, false otherwise.
function vim.fn.create_undo_point()
    local is_insert = vim.api.nvim_get_mode().mode == 'i'

    if is_insert then
        vim.api.nvim_feedkeys(undo_command, 'n', false)
    end

    return is_insert
end

---@alias vim.fn.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target vim.fn.Target # the target to expand
---@return integer, string, boolean # the buffer and the path and whether the buffer corresponds to the path
function vim.fn.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(target) then
            return 0, '', false
        end

        local path = vim.api.nvim_buf_get_name(target)
        if not path or path == '' then
            return target, '', false
        end

        return target, ide.fs.expand_path(path) or path, true
    elseif type(target) == 'string' then
        ---@cast target string
        if target == '' then
            return vim.api.nvim_get_current_buf(), '', false
        end

        local path = ide.fs.expand_path(target) or target

        for _, buf in ipairs(vim.buf.get_listed_buffers { loaded = false }) do
            local buf_path = vim.api.nvim_buf_get_name(buf)
            if buf_path and buf_path ~= '' and ide.fs.expand_path(buf_path) == path then
                return buf, path, true
            end
        end

        return vim.api.nvim_get_current_buf(), path, false
    else
        error 'Invalid target type'
    end
end

--- Gets the width of the status column
---@param window integer|nil # the window to get the status column width for or the current window if nil
---@return integer|nil # the status column width or nil if the window is invalid
function vim.fn.status_column_width(window)
    window = window or vim.api.nvim_get_current_win()
    local info = vim.fn.getwininfo(window)
    if vim.api.nvim_win_is_valid(window) and info[1] then
        return info[1].textoff
    end

    return nil
end

--- Toggles a fold at a given line
---@param line integer|nil # the line to toggle the fold for or the current line if nil
---@window integer|nil # the window to use for the operation or the current window if nil
---@return boolean|nil # true if the fold was opened, false if it was closed, nil if the line is not foldable
function vim.fn.toggle_fold(line, window)
    window = window or vim.api.nvim_get_current_win()
    line = line or vim.api.nvim_win_get_position(window)[1]

    assert(type(line) == 'number' and line >= 0)
    assert(type(window) == 'number')

    return vim.api.nvim_win_call(window, function()
        if vim.fn.foldclosed(line) == line then
            vim.cmd(string.format('%dfoldopen', line))
            return true
        elseif vim.fn.foldlevel(line) > 0 then
            vim.cmd(string.format('%dfoldclose', line))
            return false
        end

        return nil
    end)
end

--- Gets the state of a fold marker at a given line (where fold starts)
---@param line integer|nil # the line to get the fold state for or the current line if nil
---@param window integer|nil # the window to use for the operation or the current window if nil
---@return boolean|nil # true if the fold marker should show "closed", false if it is "open", nil if no marker
function vim.fn.fold_marker(line, window)
    window = window or vim.api.nvim_get_current_win()
    line = line or vim.api.nvim_win_get_position(window)[1]

    assert(type(line) == 'number' and line >= 0)
    assert(type(window) == 'number')

    return vim.api.nvim_win_call(window, function()
        if vim.fn.foldclosed(line) >= 0 then
            return true
        elseif tostring(vim.treesitter.foldexpr(line)):sub(1, 1) == '>' then
            return false
        end

        return nil
    end)
end

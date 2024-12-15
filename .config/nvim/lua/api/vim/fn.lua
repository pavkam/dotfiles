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

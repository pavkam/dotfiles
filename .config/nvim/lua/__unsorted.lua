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

---@class __unsorted
vim.buf = {}

vim.buf.special_file_types = {
    'neo-tree',
    'dap-float',
    'dap-repl',
    'dapui_console',
    'dapui_watches',
    'dapui_stacks',
    'dapui_breakpoints',
    'dapui_scopes',
    'PlenaryTestPopup',
    'help',
    'lspinfo',
    'man',
    'notify',
    'noice',
    'Outline',
    'qf',
    'query',
    'spectre_panel',
    'startuptime',
    'tsplayground',
    'checkhealth',
    'Trouble',
    'terminal',
    'neotest-summary',
    'neotest-output',
    'neotest-output-panel',
    'WhichKey',
    'TelescopePrompt',
    'TelescopeResults',
}

vim.buf.special_buffer_types = {
    'prompt',
    'nofile',
    'terminal',
    'help',
}

vim.buf.transient_buffer_types = {
    'nofile',
    'terminal',
}

vim.buf.transient_file_types = {
    'gitcommit',
    'gitrebase',
    'hgcommit',
}

---@class (exact) vim.buf.GetListedBufferOpts
---@field loaded boolean|nil # whether to get only loaded buffers (default) true
---@field listed boolean|nil # whether to get only listed buffers (default) true

--- Gets the list of listed file buffers
---@param opts vim.buf.GetListedBufferOpts|nil # the options to get the buffers
---@return integer[] # the list of buffers
function vim.buf.get_listed_buffers(opts)
    opts = opts or {}
    opts.loaded = opts.loaded == nil and true or opts.loaded
    opts.listed = opts.listed == nil and true or opts.listed

    return vim.iter(vim.api.nvim_list_bufs())
        :filter(
            ---@param b integer
            function(b)
                if not vim.api.nvim_buf_is_valid(b) then
                    return false
                end
                if opts.listed and not vim.api.nvim_get_option_value('buflisted', { buf = b }) then
                    return false
                end
                if opts.loaded and not vim.api.nvim_buf_is_loaded(b) then
                    return false
                end

                return true
            end
        )
        :totable()
end

--- Checks if a buffer is a special buffer
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a special buffer, false otherwise
function vim.buf.is_special(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buffer) then
        return true
    end

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    ---@type boolean
    return buftype ~= ''
        and (
            vim.tbl_contains(vim.buf.special_buffer_types, buftype)
            or vim.tbl_contains(vim.buf.special_file_types, filetype)
        )
end

--- Checks if a buffer is a transient buffer (a file which we should not deal with)
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a transient buffer, false otherwise
function vim.buf.is_transient(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buffer) then
        return false
    end

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    if buftype == '' and filetype == '' then
        return true
    end

    ---@type boolean
    return (
        vim.tbl_contains(vim.buf.transient_buffer_types, buftype)
        or vim.tbl_contains(vim.buf.transient_file_types, filetype)
    )
end

--- Checks whether a buffer is a regular buffer (normal file)
---@param buffer integer|nil # the buffer to check, or the current buffer if 0 or nil
---@return boolean # whether the buffer is valid for formatting
function vim.buf.is_regular(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(buffer) then
        return false
    end

    ---@type boolean
    return vim.api.nvim_buf_is_valid(buffer) and not vim.buf.is_special(buffer) and not vim.buf.is_transient(buffer)
end

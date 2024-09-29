---@class vim.buf
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

---@class (exact) vim.buf.DeleteBufferOpts # options for deleting a buffer
---@field force boolean|nil # whether to force the deletion of the buffer

--- Removes a buffer
---@param buffer integer|nil # the buffer to remove or the current buffer if 0 or nil
---@param opts vim.buf.DeleteBufferOpts|nil # the options for deleting the buffer
function vim.buf.delete(buffer, opts)
    buffer = buffer or vim.api.nvim_get_current_buf()
    opts = opts or {}

    local should_remove = opts.force or vim.fn.confirm_saved(buffer, 'closing')

    if vim.list_contains(vim.filetype.pinned(), vim.api.nvim_get_option_value('filetype', { buf = buffer })) then
        for _, window in ipairs(vim.fn.getbufinfo(buffer)[1].windows) do
            vim.api.nvim_win_close(window, true)
        end
    end

    if should_remove then
        for _, win in ipairs(vim.fn.win_findbuf(buffer)) do
            vim.api.nvim_win_call(win, function()
                if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buffer then
                    return
                end

                -- Try using alternate buffer
                local alt = vim.fn.bufnr '#'
                if alt ~= buffer and vim.fn.buflisted(alt) == 1 then
                    vim.api.nvim_win_set_buf(win, alt)
                    return
                end

                -- Try using previous buffer
                local has_previous = pcall(vim.cmd --[[@as function]], 'bprevious')
                if has_previous and buffer ~= vim.api.nvim_win_get_buf(win) then
                    return
                end

                -- Create new listed buffer
                local new_buf = vim.api.nvim_create_buf(true, false)
                vim.api.nvim_win_set_buf(win, new_buf)
            end)
        end

        if vim.api.nvim_buf_is_valid(buffer) then
            pcall(vim.cmd --[[@as function]], 'bdelete! ' .. buffer)
        end
    end
end

--- Removes other buffers (except the specified one)
---@param buffer integer|nil # the buffer to keep or the current buffer if 0 or nil
---@param opts vim.buf.DeleteBufferOpts|nil # the options for deleting the buffer
function vim.buf.delete_others(buffer, opts)
    buffer = buffer or vim.api.nvim_get_current_buf()

    for _, b in ipairs(vim.buf.get_listed_buffers { loaded = false }) do
        if b ~= buffer then
            vim.buf.delete(b, opts)
        end
    end
end

--- Checks if a buffer is a special buffer
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a special buffer, false otherwise
function vim.buf.is_special(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

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

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    if buftype == '' and filetype == '' then
        return true
    end

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
    return vim.api.nvim_buf_is_valid(buffer) and not vim.buf.is_special(buffer) and not vim.buf.is_transient(buffer)
end

--- Get the line of the buffer in whatever window it is displayed
---@param buffer integer|nil # the buffer to get the line of, or the current buffer if 0 or nil
function vim.buf.cursor_line(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local win = vim.fn.bufwinid(buffer)
    if not vim.api.nvim_win_is_valid(win) then
        return vim.api.nvim_buf_get_mark(buffer, [["]])[1]
    end

    return vim.api.nvim_win_get_cursor(win)[1]
end

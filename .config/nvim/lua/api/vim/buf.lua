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

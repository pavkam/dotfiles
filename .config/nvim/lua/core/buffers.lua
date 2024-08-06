local utils = require 'core.utils'

---@class core.buffers
local M = {}

---@class (exact) core.buffers.GetListedBufferOpts
---@field loaded boolean|nil # whether to get only loaded buffers (default) true
---@field listed boolean|nil # whether to get only listed buffers (default) true

--- Gets the list of listed file buffers
---@param opts core.buffers.GetListedBufferOpts|nil # the options to get the buffers
---@return integer[] # the list of buffers
function M.get_listed_buffers(opts)
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

--- Checks if a buffer is loaded
--- @param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
function M.buffer_is_loaded(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer)
end

--- Gets the buffer by its index in the list of listed buffers
---@param index integer # the index of the buffer to get
---@return integer|nil # the index of the buffer in the list of listed buffers or nil if the buffer is not listed
function M.get_buffer_by_index(index)
    assert(type(index) == 'number' and index > 0)

    for i, b in ipairs(M.get_listed_buffers { loaded = false }) do
        if i == index then
            return b
        end
    end

    return nil
end

--- Removes a buffer
---@param buffer integer|nil # the buffer to remove or the current buffer if 0 or nil
function M.remove_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local should_remove = utils.confirm_saved(0, 'closing')
    if should_remove then
        local buffers = M.get_listed_buffers { loaded = false }

        require('mini.bufremove').delete(buffer, true)

        -- Special code to manage alpha
        if vim.has_plugin 'alpha-nvim' then
            if #buffers == 1 and buffers[1] == buffer then
                require('alpha').start()
                vim.schedule(function()
                    for _, b in ipairs(M.get_listed_buffers()) do
                        vim.api.nvim_buf_delete(b, { force = true })
                    end
                end)
            end
        end
    end
end

--- Removes other buffers (except the current one)
---@param buffer integer|nil # the buffer to remove or the current buffer if 0 or nil
function M.remove_other_buffers(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    for _, b in ipairs(M.get_listed_buffers { loaded = false }) do
        if b ~= buffer then
            M.remove_buffer(b)
        end
    end
end

M.special_file_types = {
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

M.special_buffer_types = {
    'prompt',
    'nofile',
    'terminal',
    'help',
}

M.transient_buffer_types = {
    'nofile',
    'terminal',
}

M.transient_file_types = {
    'gitcommit',
    'gitrebase',
    'hgcommit',
}

--- Checks if a buffer is a special buffer
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a special buffer, false otherwise
function M.is_special_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    return buftype ~= ''
        and (vim.tbl_contains(M.special_buffer_types, buftype) or vim.tbl_contains(M.special_file_types, filetype))
end

--- Checks if a buffer is a transient buffer (a file which we should not deal with)
---@param buffer integer|nil # the buffer to check or the current buffer if 0 or nil
---@return boolean # true if the buffer is a transient buffer, false otherwise
function M.is_transient_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buffer })
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buffer })

    if buftype == '' and filetype == '' then
        return true
    end

    return (vim.tbl_contains(M.transient_buffer_types, buftype) or vim.tbl_contains(M.transient_file_types, filetype))
end

--- Checks whether a buffer is a regular buffer (normal file)
---@param buffer integer|nil # the buffer to check, or the current buffer if 0 or nil
---@return boolean # whether the buffer is valid for formatting
function M.is_regular_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    return vim.api.nvim_buf_is_valid(buffer) and not M.is_special_buffer(buffer) and not M.is_transient_buffer(buffer)
end

return M

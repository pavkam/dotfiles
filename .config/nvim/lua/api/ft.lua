local fs = require 'api.fs'

---@type table<string, string>
local file_to_file_type = {}

--- Gets the file type of a file.
---@param file_path string # the path to the file to get the type for.
---@return string|nil # the file type or nil if the file type could not be determined.
local function detect(file_path)
    xassert {
        file_path = { file_path, { 'string', ['>'] = 0 } },
    }

    file_path = fs.expand_path(file_path) or file_path

    ---@type string|nil
    local file_type = file_to_file_type[file_path]
    if file_type then
        return file_type
    end

    file_type = vim.filetype.match { filename = file_path }
    if not file_type then
        for _, buf in ipairs(vim.fn.getbufinfo()) do
            if fs.expand_path(buf.name) == file_path or buf.name == file_path then
                return vim.filetype.match { buf = buf.bufnr }
            end
        end

        local bufn = vim.fn.bufadd(file_path)
        vim.fn.bufload(bufn)

        file_type = vim.filetype.match { buf = bufn }

        vim.api.nvim_buf_delete(bufn, { force = true })
    end

    file_to_file_type[file_path] = file_type

    return file_type
end

---@alias ft.option_type # The supported file type options.
---| 'keep_undo_history' # whether to keep undo history.
---| 'keep_swap_file' # whether to keep a swap file.
---| 'auto_read' # whether to automatically read the file.
---| 'is_binary' # whether the file is binary.
---| 'is_listed' # whether the file is listed.
---| 'is_hidden' # whether the file is hidden.
---| 'is_readonly' # whether the file is read-only.
---| 'is_modifiable' # whether the file is modifiable.
---| 'comment_format' # the comment format.
---| 'show_cursorline' # whether to show the cursor line.
---| 'spell_check' # whether the file is spell checked.
---| 'spell_file_path' # the path to the spell file.
---| 'wrap_enabled' # whether wrapping is enabled.
---| 'show_sign_column' # the sign column to show.
---| 'pinned_to_window' # whether the file is pinned to the window.

-- The supported file type options.
---@type table<ft.option_type, { [1]: string, [2]: xtype }>
local supported_options = {
    keep_undo_history = { 'undofile', 'boolean' },
    keep_swap_file = { 'swapfile', 'boolean' },
    auto_read = { 'autoread', 'boolean' },
    is_binary = { 'binary', 'boolean' },
    is_listed = { 'buflisted', 'boolean' },
    is_hidden = { 'bufhidden', 'boolean' },
    is_readonly = { 'readonly', 'boolean' },
    is_modifiable = { 'modifiable', 'boolean' },
    comment_format = { 'commentstring', 'string' },
    show_cursorline = { 'cursorline', 'boolean' },
    spell_check = { 'spell', 'boolean' },
    spell_file_path = { 'spellfile', 'string' },
    wrap_enabled = { 'wrap', 'boolean' },
    show_sign_column = { 'signcolumn', 'string' },
    pinned_to_window = { 'winfixbuf', 'boolean' },
}

-- Gets an option for a file type.
---@param file_type string # the file type to get the option for.
---@param option ft.option_type # the option to get.
---@return boolean, boolean|string|integer|nil # the option value.
local function get_file_type_option(file_type, option)
    local actual_option = supported_options[option]
    if not actual_option then
        return false, nil
    end

    return true, vim.filetype.get_option(file_type, actual_option[1])
end

-- Sets an option for a file type.
---@param file_type string # the file type to set the option for.
---@param option string # the option to set.
---@param value boolean|string|integer # the value to set the option to.
---@return boolean # whether the option was set successfully.
local function set_file_type_option(file_type, option, value)
    xassert {
        file_type = { file_type, { 'string', ['>'] = 0 } },
        option = { option, { 'string', ['>'] = 0 } },
        value = { value, { 'boolean', 'string', 'number' } },
    }

    for _, buffer_id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buffer_id].filetype == file_type then
            vim.opt_local[buffer_id][option] = value
        end
    end

    return true
end

-- Gets the supported file type options.
---@return string[] # the list of supported options.
local function get_file_type_option_names()
    return vim.tbl_keys(supported_options)
end

-- File type management.
---@class ft
---@field detect fun(file_type: string): boolean # Detects the file type of a file.
---@field [ft.option_type] boolean|string|integer # The options for a file type.
local M = table.synthetic({ detect }, {
    ---@param file_type string
    getter = function(file_type)
        xassert {
            file_type = { file_type, { 'string', ['>'] = 0 } },
        }

        return true,
            table.synthetic({}, {
                getter = function(option)
                    local ok, value = get_file_type_option(file_type, option)
                    return ok, value
                end,
                setter = function(option, value)
                    return set_file_type_option(file_type, option, value)
                end,
                enumerate = get_file_type_option_names,
                store = true,
            })
    end,
})

vim.api.nvim_create_autocmd('FileType', {
    callback = function(evt)
        local options = M[evt.match]
        for option, value in pairs(options) do
            vim.opt_local[assert(supported_options[option])[1]] = value
        end
    end,
    group = vim.api.nvim_create_augroup('api.ft.apply_file_type_options', { clear = true }),
})

return M

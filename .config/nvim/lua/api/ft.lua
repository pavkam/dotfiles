local fs = require 'api.fs'

---@type table<string, string>
local file_to_file_type = {}

--- Gets the file type of a file.
---@param file_path string # the path to the file to get the type for.
---@return string|nil # the file type or nil if the file type could not be determined.
local function detect(file_path)
    assert(type(file_path) == 'string' and file_path ~= '')
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

---@enum api.ft.OptionType
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
    is_spell_checked = { 'spell', 'boolean' },
    spell_file_path = { 'spellfile', 'string' },
    wrap_enabled = { 'wrap', 'boolean' },
    show_sign_column = { 'signcolumn', 'string' },
    pinned_to_window = { 'winfixbuf', 'boolean' },
}

-- Gets an option for a file type.
---@param file_type string # the file type to get the option for.
---@param option api.ft.OptionType # the option to get.
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

-- Provides access to file type options.
---@class  api.ft # Exposes file type related functionality.
---@field detect fun(file_path: string): string|nil # Gets the file type of a file.
---@field [string] { [api.ft.OptionType]: boolean|string|integer } # Provides access to file type options.

---@type api.ft
local M = table.synthetic({ detect }, {
    ---@param file_type string
    getter = function(file_type)
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
                cache = false,
            })
    end,
})

vim.api.nvim_create_autocmd('FileType', {
    callback = function(evt)
        local options = M[evt.match]
        for option, value in pairs(options) do
            vim.opt_local[evt.bur][option] = value
        end
    end,
    group = vim.api.nvim_create_augroup('api.ft.apply_file_type_options', { clear = true }),
})

return M

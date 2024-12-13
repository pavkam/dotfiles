local fs = require 'api.fs'

---@type table<string, string>
local file_to_file_type = {}

---@class (exact) file_type # Stores information about a file type.
---@field id string # the unique identifier of the file type.
---@field keep_undo_history boolean # whether to keep undo history.
---@field keep_swap_file boolean # whether to keep a swap file.
---@field auto_read boolean # whether to automatically read the file.
---@field is_binary boolean # whether the file is binary.
---@field is_listed boolean # whether the file is listed.
---@field is_hidden boolean # whether the file is hidden.
---@field is_readonly boolean # whether the file is read-only.
---@field is_modifiable boolean # whether the file is modifiable.
---@field comment_format string # the comment format.
---@field show_cursorline boolean # whether to show the cursor line.
---@field spell_check boolean # whether the file is spell checked.
---@field spell_file_path string # the path to the spell file.
---@field wrap_enabled boolean # whether wrapping is enabled.
---@field show_sign_column string # the sign column to show.
---@field pinned_to_window boolean # whether the file is pinned to the window.

---@class (exact) ft # Provides information about file types.
---@field [string] file_type # the details of a file type.
---@field detect fun(file_path: string): string|nil # Detects the file type of a file.

---@type table<string, { [1]: string, [2]: 'bo'|'wo', [3]: xtype }>
local properties = {
    keep_undo_history = { 'undofile', 'bo', 'boolean' },
    keep_swap_file = { 'swapfile', 'bo', 'boolean' },
    auto_read = { 'autoread', 'bo', 'boolean' },
    is_binary = { 'binary', 'bo', 'boolean' },
    is_listed = { 'buflisted', 'bo', 'boolean' },
    is_hidden = { 'bufhidden', 'bo', 'boolean' },
    is_readonly = { 'readonly', 'bo', 'boolean' },
    is_modifiable = { 'modifiable', 'bo', 'boolean' },
    comment_format = { 'commentstring', 'bo', 'string' },
    show_cursorline = { 'cursorline', 'wo', 'boolean' },
    spell_check = { 'spell', 'wo', 'boolean' },
    spell_file_path = { 'spellfile', 'wo', 'string' },
    wrap_enabled = { 'wrap', 'wo', 'boolean' },
    show_sign_column = { 'signcolumn', 'wo', 'string' },
    pinned_to_window = { 'winfixbuf', 'wo', 'boolean' },
}

-- The file type API.
---@type ft
local M = table.smart {
    entity_properties = table.map(
        properties,
        ---@param option { [1]: string, [2]: 'bo'|'wo', [3]: xtype }>
        function(option)
            return {
                ---@param file_type file_type
                ---@return boolean|string|integer|nil
                get = function(_, file_type)
                    return vim.filetype.get_option(file_type.id, option[1])
                end,
                ---@param file_type file_type
                ---@param value boolean|string|integer
                set = function(_, file_type, value)
                    xassert {
                        value = { value, option[3] },
                    }

                    for _, buffer in ipairs(require 'api.buf') do
                        if buffer.file_type == file_type.id then
                            vim[option[2]][buffer.id][option] = value
                        end
                    end
                end,
                cache = true,
            }
        end
    ),
    functions = {
        ---@param t ft
        ---@param file_path string
        ---@return file_type
        detect = function(t, file_path)
            xassert {
                file_path = { file_path, { 'string', ['>'] = 0 } },
            }

            file_path = fs.expand_path(file_path) or file_path

            ---@type string|nil
            local file_type = file_to_file_type[file_path]
            if file_type then
                return t[file_type]
            end

            file_type = vim.filetype.match { filename = file_path }
            if not file_type then
                local buffers = require 'api.buf'
                for _, buffer in ipairs(buffers) do
                    if buffer.file_path == file_path then
                        return vim.filetype.match { buf = buffer.id }
                    end
                end

                local buffer = buffers.load(file_path)
                if buffer then
                    file_type = vim.filetype.match { buf = buffer.id }
                    buffer.remove { force = true }
                end
            end

            file_to_file_type[file_path] = file_type
            return t[file_type]
        end,
    },
    ---@param file_type string
    ---@return boolean
    entity_id_valid = function(file_type)
        return type(file_type) == 'string' and #file_type > 0
    end,
}

-- Apply the file type options to the current buffer.
---@param file_type string
local function apply_file_type_options(file_type)
    xassert {
        file_type = { file_type, 'string' },
    }

    local options = M[file_type]
    if not options then
        return
    end

    for option, value in pairs(options) do
        local p = assert(properties[option])
        vim[p[2]][p[1]] = value
    end
end

local auto_group = vim.api.nvim_create_augroup('ft.apply_file_type_options', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
    callback = function(evt)
        apply_file_type_options(evt.match)
    end,
    group = auto_group,
})

vim.api.nvim_create_autocmd('BufWinEnter', {
    callback = function(evt)
        apply_file_type_options(vim.bo[evt.buf].filetype)
    end,
    group = auto_group,
})

return M

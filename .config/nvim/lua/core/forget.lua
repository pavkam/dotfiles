local utils = require 'core.utils'
local marks = require 'ui.marks'
local old_files = require 'core.old_files'

--- Gets all windows in Vim
---@return integer[] # a list of window handles
local function all_windows()
    local windows = {}
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        vim.list_extend(windows, vim.api.nvim_tabpage_list_wins(tabpage))
    end

    return vim.tbl_filter(function(win)
        return vim.api.nvim_win_is_valid(win)
    end, windows)
end

---@class utils.forget.QuickFixEntry
---@field bufnr number # the buffer number
---@field col number # the column number
---@field end_col number # the end column number
---@field end_lnum number # the end line number
---@field filename string # the file name
---@field lnum number # the line number
---@field nr number # the error number
---@field pattern string # the search pattern used to locate the error
---@field text string # the description of the error
---@field type string # the type of the error, 'E', '1', etc.
---@field valid integer # whether the error message is recognized

--- Forget all quick fix references
---@param file string # the file to forget
local function forget_qf_list(file)
    assert(type(file) == 'string' and file ~= '')

    ---@type utils.forget.QuickFixEntry[]
    local qf_list = vim.fn.getqflist()

    qf_list = vim.tbl_filter(function(item)
        return item.filename ~= file
    end, qf_list)

    vim.fn.setqflist(qf_list)
end

--- Forget all location list references
---@param file string # the file to forget
local function forget_loc_list(file)
    assert(type(file) == 'string' and file ~= '')

    for _, win in ipairs(all_windows()) do
        ---@type utils.forget.QuickFixEntry[]
        local loc_list = vim.tbl_filter(function(item)
            ---@cast item utils.forget.QuickFixEntry
            return item.filename ~= file
        end, vim.fn.getloclist(win))

        vim.fn.setloclist(win, loc_list)
    end
end

--- Forget all references to a file
---@param file string
local function forget_file(file)
    assert(type(file) == 'string' and file ~= '')

    old_files.forget(file)
    marks.forget(file)
    forget_qf_list(file)
    forget_loc_list(file)
end

-- forget files that have been deleted
utils.on_event('BufDelete', function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or utils.file_exists(file) then
        return
    end

    forget_file(file)
end)

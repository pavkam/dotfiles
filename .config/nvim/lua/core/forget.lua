local utils = require 'core.utils'

--- Gets all windows in Vim
---@return integer[] # a list of window handles
local function all_windows()
    local windows = vim.api.nvim_list_wins()
    local tabpages = vim.api.nvim_list_tabpages()

    for _, tabpage in ipairs(tabpages) do
        vim.list_extend(windows, vim.api.nvim_tabpage_list_wins(tabpage))
    end

    return vim.tbl_filter(function(win)
        return vim.api.nvim_win_is_valid(win)
    end, windows)
end

--- Forget all oldfiles references
---@param file string # the file to forget
local function forget_old_files(file)
    for i, old_file in ipairs(vim.v.oldfiles) do
        if old_file == file then
            vim.cmd('call remove(v:oldfiles, ' .. (i - 1) .. ')')
            break
        end
    end
end

---@class utils.forget.JumpListEntry
---@field bufnr number
---@field col number
---@field coladd number
---@field filename string
---@field lnum number

--- Forget all jump list references
---@param file string # the file to forget
local function forget_jump_list(file)
    assert(type(file) == 'string' and file ~= '')

    for _, win in ipairs(all_windows()) do
        ---@type utils.forget.JumpListEntry[]
        local jump_list
        vim.api.nvim_win_call(win, function()
            jump_list = vim.fn.getjumplist()[1] -- TODO: can we simplify this?
        end)

        for i, entry in ipairs(jump_list) do
            if entry.filename == file then
                vim.cmd('call remove(getjumplist()[1], ' .. (i - 1) .. ')')
            end
        end
    end
end

--- Forget all global marks references
---@param file string # the file to forget
local function forget_global_marks(file)
    assert(type(file) == 'string' and file ~= '')

    ---@type utils.marks.Mark[]
    local marks = vim.fn.getmarklist()

    for _, mark in ipairs(marks) do
        if mark.file == file then
            vim.api.nvim_del_mark(string.sub(mark.mark, -1))
        end
    end
end

--- Forget all local marks references
---@param file string # the file to forget
local function forget_local_marks(file)
    assert(type(file) == 'string' and file ~= '')

    local bufnr = vim.fn.bufnr(file --[[@as integer]], 1) -- TODO: test this actually works

    ---@type utils.marks.Mark[]
    local marks = vim.fn.getmarklist(bufnr)

    for _, mark in ipairs(marks) do
        if mark.mark ~= "'." and mark.mark ~= "'^" then
            vim.api.nvim_buf_del_mark(bufnr, string.sub(mark.mark, -1))
        end
    end
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
function forget_file(file)
    assert(type(file) == 'string' and file ~= '')

    forget_old_files(file)
    forget_jump_list(file)
    forget_global_marks(file)
    forget_local_marks(file)
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

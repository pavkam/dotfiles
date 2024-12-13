local events = require 'events'
local keys = require 'keys'

local group = 'pavkam_marks'

---@class ui.marks
local M = {}

ide.theme.register_highlight_groups {
    MarkSign = 'DiagnosticWarn',
}

---@class (exact) ui.marks.Mark # A mark.
---@field mark string # the mark name.
---@field pos number[] # the position of the mark.
---@field file string|nil # the file of the mark.

---@class (exact) ui.marks.SerializedMark # A serialized mark.
---@field mark string # the mark name.
---@field lnum number # the line number of the mark.
---@field col number # the column number of the mark.

---@alias ui.marks.SerializedMarks table<string, ui.marks.SerializedMark[]>

--- Gets the name of a mark.
---@param mark ui.marks.Mark # the mark.
---@return string # the name of the mark.
local function mark_key(mark)
    return mark.mark:sub(2, 2)
end

--- Checks if a mark is a user mark
---@param mark ui.marks.Mark|string # the mark.
---@return boolean # whether the mark is a user mark.
local function is_user_mark(mark)
    local key = type(mark) == 'string' and mark or mark_key(mark --[[@as ui.marks.Mark]])
    return key:match '^[a-zA-Z]$' ~= nil
end

--- Checks if a mark is a buffer mark.
---@param mark ui.marks.Mark|string # the mark.
---@return boolean # whether the mark is a buffer mark.
local function is_buffer_mark(mark)
    local key = type(mark) == 'string' and mark or mark_key(mark --[[@as ui.marks.Mark]])
    return key:match '^[a-z]$' ~= nil
end

--- Gets the marks for a buffer.
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer.
---@return ui.marks.Mark[] # a list of marks.
local get_marks = function(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local marks = {}

    vim.list_extend(marks, vim.fn.getmarklist(buffer))
    vim.list_extend(marks, vim.fn.getmarklist())

    return vim.iter(marks)
        :filter(function(mark)
            return mark.pos[1] == buffer and is_user_mark(mark)
        end)
        :totable()
end

--- Updates the signs for a buffer.
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer.
local function update_signs(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    vim.fn.sign_unplace(group, { buffer = buffer })

    for i, mark in pairs(get_marks(buffer)) do
        local key = mark_key(mark)
        local signName = 'mark_' .. key

        vim.fn.sign_define(signName, { text = key, texthl = 'MarkSign' })
        vim.fn.sign_place(0, group, signName, buffer, { lnum = mark.pos[2], priority = -100 + i })
    end

    vim.cmd.redrawstatus()
end

--- Sets a mark at the given position.
---@param mark string # the mark character.
---@param line integer # the line number.
---@param col integer # the column number.
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer or global.
function M.set(mark, line, col, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    assert(type(mark) == 'string' and is_user_mark(mark))
    assert(type(line) == 'number' and line > 0)
    assert(type(col) == 'number' and col >= 0)

    vim.api.nvim_buf_set_mark(buffer, mark, line, col, {})
    ide.tui.info(string.format('Added `%s` mark to position **%d:%d**.', mark, line, col))

    update_signs(is_buffer_mark(mark) and buffer or nil)
end

--- Removes a mark.
---@param mark string # the mark character.
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer or global.
function M.delete(mark, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    assert(type(mark) == 'string' and is_user_mark(mark))

    local deleted = is_buffer_mark(mark) and vim.api.nvim_buf_del_mark(buffer, mark) or vim.api.nvim_del_mark(mark)

    if deleted then
        ide.tui.info(string.format('Removed the `%s` mark.', mark))
        update_signs(is_buffer_mark(mark) and buffer or nil)
    else
        ide.tui.hint(string.format('Mark `%s` is not set.', mark))
    end
end

--- Removes all marks from from a given position.
---@param line integer # the line number.
---@param col integer # the column number.
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer or global.
function M.delete_all(line, col, buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    assert(type(line) == 'number' and line > 0)
    assert(type(col) == 'number' and col >= 0)

    for _, mark in pairs(get_marks(buffer)) do
        if mark.pos[2] == line then
            M.delete(mark_key(mark), buffer)
        end
    end
end

keys.attach(nil, function(set)
    set('n', 'm', function()
        local key = vim.fn.getcharstr()
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))

        if key == '-' then
            M.delete_all(line, col)
            return
        elseif is_user_mark(key) then
            M.set(key, line, col)
        end
    end, { desc = 'Manage mark on current line' })
end, true)

-- restore marks after reloading a file
events.on_event('BufEnter', function(evt)
    if vim.buf.is_special(evt.buf) then
        return
    end

    vim.schedule(function()
        update_signs(evt.buf)
    end)
end)

events.on_event('CmdlineLeave', function(evt)
    vim.schedule(function()
        local last_cmd = vim.fn.getreg ':'
        if last_cmd:match '^delm' then
            update_signs(evt.buf)
        end
    end)
end, ':')

--- Forget all global marks references for a file
---@param file string # the file to forget
function M.forget(file)
    assert(type(file) == 'string' and file ~= '')

    ---@type ui.marks.Mark[]
    local marks = vim.fn.getmarklist()

    for _, mark in ipairs(marks) do
        if mark.file == file then
            vim.api.nvim_del_mark(mark_key(mark))
        end
    end
end

return M

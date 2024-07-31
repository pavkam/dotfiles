local utils = require 'core.utils'
local keys = require 'core.keys'

local group = 'pavkam_marks'

---@class ui.marks
local M = {}

---@class ui.marks.Mark
---@field mark string # the mark name
---@field pos number[] # the position of the mark
---@field file string|nil # the file of the mark

---@class ui.marks.SerializedMark
---@field mark string # the mark name
---@field lnum number # the line number of the mark
---@field col number # the column number of the mark

---@alias ui.marks.SerializedMarks table<string, ui.marks.SerializedMark[]>

--- Gets the name of a mark
---@param mark ui.marks.Mark # the mark
---@return string # the name of the mark
local function mark_key(mark)
    return mark.mark:sub(2, 2)
end

--- Checks if a mark is a user mark
---@param mark ui.marks.Mark|string # the mark
---@return boolean # whether the mark is a user mark
local function is_user_mark(mark)
    local key = type(mark) == 'string' and mark or mark_key(mark --[[@as ui.marks.Mark]])
    return key:match '[a-zA-Z0-9]'
end

--- Checks if a mark is a buffer mark
---@param mark ui.marks.Mark|string # the mark
---@return boolean # whether the mark is a buffer mark
local function is_buffer_mark(mark)
    local key = type(mark) == 'string' and mark or mark_key(mark --[[@as ui.marks.Mark]])
    return key:match '[a-z]'
end

--- Gets the marks for a buffer
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer
---@return ui.marks.Mark[] # a list of marks
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

--- Updates the signs for a buffer
---@param buffer integer|nil # the buffer number, or 0 or nil for the current buffer
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

    if package.loaded['satellite'] then
        local s = require 'satellite.view'
        s.refresh_bars()
    end
end

---@type string[]
local letters = {}
for i = 97, 122 do -- ASCII values for 'a' to 'z'
    table.insert(letters, string.char(i))
    table.insert(letters, string.char(i - 32))
end

keys.attach(nil, function(set)
    for _, key in ipairs(letters) do
        set('n', 'm' .. key, function()
            local r, c = unpack(vim.api.nvim_win_get_cursor(0))

            vim.api.nvim_buf_set_mark(0, key, r, c, {})
            utils.info(string.format('Marked position **%d:%d** as `%s`.', r, c, key))

            update_signs()
        end, { desc = string.format('Set mark "%s" at current line', key) })
    end

    set('n', 'm-', function()
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))

        for _, mark in pairs(get_marks()) do
            if mark.pos[2] == r then
                local key = mark_key(mark)
                utils.info(string.format('Unmarked position **%d:%d** as `%s`.', r, c, key))

                if is_buffer_mark(key) then
                    vim.api.nvim_buf_del_mark(0, key)
                else
                    vim.api.nvim_del_mark(key)
                end
            end
        end

        update_signs()
    end, { desc = 'Remove mark from the current line' })
end, true)

utils.on_event('BufEnter', function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    vim.schedule(function()
        update_signs(evt.buf)
    end)
end)

-- restore marks after reloading a file
utils.on_event({ 'BufReadPost', 'BufNew' }, function(evt)
    if utils.is_special_buffer(evt.buf) or utils.is_transient_buffer(evt.buf) then
        return
    end

    -- restore cursor position
    local cursor_mark = vim.api.nvim_buf_get_mark(evt.buf, '"')
    if cursor_mark[1] > 0 and cursor_mark[1] <= vim.api.nvim_buf_line_count(evt.buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, cursor_mark)
    end
end)

utils.on_event('CmdlineLeave', function(evt)
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

local utils = require 'core.utils'
local group = 'pavkam_marks'

---@class ui.marks
local M = {}

---@class ui.marks.Mark
---@field mark string # the mark name
---@field pos number[] # the position of the mark
---@field file? string # the file of the mark

---@class ui.marks.SerializedMark
---@field mark string # the mark name
---@field lnum number # the line number of the mark
---@field col number # the column number of the mark

---@alias ui.marks.SerializedMarks table<string, ui.marks.SerializedMark[]>

---@type ui.marks.SerializedMarks
local file_mark_history = {}

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
---@param buffer? integer # the buffer number, or 0 or nil for the current buffer
---@return ui.marks.Mark[] # a list of marks
local get_marks = function(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local marks = {}

    vim.list_extend(marks, vim.fn.getmarklist(buffer))
    vim.list_extend(marks, vim.fn.getmarklist())

    return vim.tbl_filter(function(mark)
        return mark.pos[1] == buffer and is_user_mark(mark)
    end, marks)
end

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
end

utils.attach_keymaps(nil, function(set)
    set('n', 'm', function()
        local key_code = vim.fn.getchar()
        local key = vim.fn.nr2char(key_code)
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))

        if key:len() == 1 and is_user_mark(key) then
            vim.api.nvim_buf_set_mark(0, key, r, c, {})
            utils.info(string.format('Marked position **%d:%d** as `%s`.', r, c, key))
        elseif key == '-' then
            for _, mark in pairs(get_marks()) do
                if mark.pos[2] == r then
                    key = mark_key(mark)
                    utils.info(string.format('Unmarked position **%d:%d** as `%s`.', r, c, key))

                    if is_buffer_mark(key) then
                        vim.api.nvim_buf_del_mark(0, key)
                    else
                        vim.api.nvim_del_mark(key)
                    end
                end
            end
        end

        update_signs()
    end, { desc = 'Update mark' })
end, true)

utils.on_event('BufEnter', function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    vim.defer_fn(function()
        update_signs(evt.buf)
    end, 0)
end)

-- restore marks after reloading a file
utils.on_event({ 'BufReadPost', 'BufNew' }, function(evt)
    if utils.is_special_buffer(evt.buf) or vim.tbl_contains({ 'gitcommit' }, vim.bo[evt.buf].filetype) then
        return
    end

    -- restore cursor position
    local cursor_mark = vim.api.nvim_buf_get_mark(evt.buf, '"')
    if cursor_mark[1] > 0 and cursor_mark[1] <= vim.api.nvim_buf_line_count(evt.buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, cursor_mark)
    end
end)

utils.on_event('BufDelete', function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' then
        return
    end

    ---@type ui.marks.SerializedMarks
    local buffer_marks = {}
    for _, mark in ipairs(vim.fn.getmarklist(evt.buf)) do
        table.insert(buffer_marks, {
            mark = mark_key(mark),
            lnum = mark.pos[2],
            col = mark.pos[3],
        })
    end

    file_mark_history[file] = buffer_marks
end)

utils.on_event('CmdlineLeave', function(evt)
    vim.defer_fn(function()
        local last_cmd = vim.fn.getreg ':'
        if last_cmd:match '^delm' then
            update_signs(evt.buf)
        end
    end, 0)
end, ':')

--- Forget all global marks references for a file
---@param file string # the file to forget
function M.forget_global(file)
    assert(type(file) == 'string' and file ~= '')

    ---@type ui.marks.Mark[]
    local marks = vim.fn.getmarklist()

    for _, mark in ipairs(marks) do
        if mark.file == file then
            vim.api.nvim_del_mark(mark_key(mark))
        end
    end
end

--- Serialize all marks to JSON
---@return string # the JSON string
function M.serialize_to_json()
    local marks = vim.fn.getmarklist()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        vim.list_extend(marks, vim.fn.getmarklist(buf))
    end

    ---@type ui.marks.SerializedMarks
    local marks_by_file = {}
    for _, mark in ipairs(marks) do
        local file = mark.file or vim.api.nvim_buf_get_name(mark.pos[1])
        if not marks_by_file[file] then
            marks_by_file[file] = {}
        end

        table.insert(marks_by_file[file], {
            mark = mark_key(mark),
            lnum = mark.pos[2],
            col = mark.pos[3],
        })
    end

    for file, m in pairs(file_mark_history) do
        if not marks_by_file[file] then
            marks_by_file[file] = {}
        end

        vim.list_extend(marks_by_file[file], m)
    end

    return vim.fn.json_encode(marks_by_file)
end

--- Deserialize marks from JSON
---@param json string # the JSON string
function M.deserialize_from_json(json)
    local obj = vim.fn.json_decode(json) --[[@as ui.marks.SerializedMarks]]
    for file, marks in pairs(obj) do
        local ok, buffer = pcall(vim.fn.bufload, file --[[@as integer]])
        if ok and buffer ~= -1 then
            for _, mark in ipairs(marks) do
                if mark.mark ~= '.' and mark.mark ~= '^' then
                    pcall(vim.api.nvim_buf_set_mark, buffer, mark.mark, mark.lnum, mark.col, {})
                end
            end
        end
    end
end

return M

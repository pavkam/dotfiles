local utils = require 'core.utils'
local group = 'pavkam_marks'

---@class utils.marks.Mark
---@field mark string # the mark name
---@field pos number[] # the position of the mark
---@field file? string # the file of the mark

--- Gets the marks for a buffer
---@param buffer? integer # the buffer number, or 0 or nil for the current buffer
---@return utils.marks.Mark[] # a list of marks
local get_marks = function(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local marks = {}

    vim.list_extend(marks, vim.fn.getmarklist(buffer))
    vim.list_extend(marks, vim.fn.getmarklist())

    return vim.tbl_filter(function(mark)
        return mark.pos[1] == buffer and mark.mark:sub(2, 2):match '[a-zA-Z]'
    end, marks)
end

local function update_signs(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    if not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    vim.fn.sign_unplace(group, { buffer = buffer })

    for i, mark in pairs(get_marks(buffer)) do
        local key = mark.mark:sub(2, 2)
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

        if key:len() == 1 and key:match '[a-zA-Z0-9]' then
            vim.api.nvim_buf_set_mark(0, key, r, c, {})
            utils.info(string.format('Marked position **%d:%d** as `%s`.', r, c, key))
        elseif key == '-' then
            for _, mark in pairs(get_marks()) do
                if mark.pos[2] == r then
                    key = mark.mark:sub(2, 2)
                    utils.info(string.format('Unmarked position **%d:%d** as `%s`.', r, c, key))

                    if key:match '[a-z]' then
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

-- go to last loc when opening a buffer
utils.on_event('BufReadPost', function(evt)
    local exclude = { 'gitcommit' }

    if vim.tbl_contains(exclude, vim.bo[evt.buf].filetype) then
        return
    end

    local mark = vim.api.nvim_buf_get_mark(evt.buf, '"')

    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(evt.buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
end)

utils.on_event('CmdlineLeave', function(evt)
    vim.defer_fn(function()
        local last_cmd = vim.fn.getreg ':'
        if last_cmd:match '^delm' then
            update_signs(evt.buf)
        end
    end, 0)
end, ':')

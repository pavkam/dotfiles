-- Editor wide functionality.
---@class editor
local M = {}

--- Checks if the editor is in the the visual mode.
---@param mode string|nil # the mode to check or the current mode if nil.
---@return boolean # true if the mode is visual, false otherwise.
function M.in_visual_mode(mode)
    xassert {
        mode = { 'nil', { 'string', ['>'] = 0 } },
    }

    mode = mode or vim.api.nvim_get_mode().mode
    return mode == 'v' or mode == 'V' or mode == ''
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode.
---@return boolean # true if the undo point was created, false otherwise.
function M.insert_undo_point()
    local is_insert = vim.api.nvim_get_mode().mode == 'i'

    if is_insert then
        vim.api.nvim_feedkeys(undo_command, 'n', false)
    end

    return is_insert
end

return table.freeze(M)

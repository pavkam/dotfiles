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

return table.freeze(M)

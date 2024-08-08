local icons = require 'ui.icons'

---@class core.utils
local M = {}

---@alias core.utils.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target core.utils.Target # the target to expand
---@return integer, string # the buffer and the path
function M.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        return target, vim.api.nvim_buf_get_name(target)
    else
        local path = vim.fn.expand(target --[[@as string]])
        return vim.api.nvim_get_current_buf(), vim.uv.fs_realpath(vim.fn.expand(path)) or path
    end
end

--- Helper function that calculates folds
function M.fold_text()
    local ok = pcall(vim.treesitter.get_parser, vim.api.nvim_get_current_buf())
    ---@diagnostic disable-next-line: undefined-field
    local ret = ok and vim.treesitter.foldtext and vim.treesitter.foldtext() or nil
    if not ret then
        ret = {
            {
                vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1],
                {},
            },
        }
    end

    table.insert(ret, { ' ' .. icons.TUI.Ellipsis })
    return ret
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode
function M.create_undo_point()
    assert(vim.api.nvim_get_mode().mode == 'i')

    vim.api.nvim_feedkeys(undo_command, 'n', false)
end

return M

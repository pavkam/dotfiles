-- general UI functionality
local icons = require 'utils.icons'
local utils = require 'utils'

M = {}

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

--- Gets the foreground color of a highlight group
---@param name string # the name of the highlight group
---@return table<string, string>|nil # the foreground color of the highlight group
function M.hl_fg_color(name)
    ---@diagnostic disable-next-line: undefined-field
    local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.api.nvim_get_hl_by_name(name, true)
    local fg = hl and hl.fg or hl.foreground

    return fg and { fg = string.format('#%06x', fg) }
end

--- Pretty prints a list
---@param list table # the list to pretty print
---@param prefix any # the prefix to use (optional)
---@param separator any|nil # the separator to use (optional)
---@return string # the pretty printed list
function M.sexy_list(list, prefix, separator)
    separator = separator or icons.TUI.ListSeparator
    prefix = prefix or icons.TUI.SelectionPrefix
    return utils.stringify(prefix) .. ' ' .. utils.tbl_join(list, ' ' .. utils.stringify(separator) .. ' ')
end

--- Gets the current cursor position in relation to the word its on
---@param window integer|nil # the window to get the cursor position for or nil for current
---@return boolean, boolean # whether the cursor is at the start of a word, whether the cursor is at the end of a word
function M.cursor_word_relation(window)
    window = window or 0

    -- get the cursor's position
    local r, c = unpack(vim.api.nvim_win_get_cursor(window))
    if not c or not r then
        return false, false
    end

    local line = vim.api.nvim_buf_get_lines(vim.fn.winbufnr(window), r - 1, r, true)[1]

    local before = string.sub(line, 1, c)
    local after = string.sub(line, c + 1, -1)

    return string.match(before, '^%s*$') == nil, string.match(after, '^%s*$') == nil
end

return M

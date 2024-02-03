---@class editor.syntax
local M = {}

--- Get the tree for the given buffer.
---@param buffer number|nil # The buffer to get the tree for. 0 or nil for the current buffer.
---@return TSNode|nil # The root node of the tree.
local function get_tree(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local ok, parser = pcall(vim.treesitter.get_parser, buffer)
    if ok and parser then
        return parser:parse()[1]:root()
    end

    return nil
end

--- Get the node at the cursor.
---@param window number|nil # The window to get the cursor position from. 0 or nil for the current window.
---@return TSNode|nil # The node at the cursor.
local function get_node_at_cursor(window)
    window = window or vim.api.nvim_get_current_win()

    local buffer = vim.api.nvim_win_get_buf(window)
    if not vim.api.nvim_buf_is_valid(buffer) then
        return nil
    end

    local tree = get_tree()
    if not tree then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(window)
    local row, col = cursor[1] - 1, cursor[2]
    local node = tree:named_descendant_for_range(row, col, row, col)

    return node
end

--- Get the node under the cursor.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@return TSNode|nil # The node under the cursor.
function M.node_under_cursor(window)
    local node = get_node_at_cursor(window)
    return node
end

--- Get the type of the node under the cursor.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@return string|nil # The type of the node under the cursor.
function M.node_type_under_cursor(window)
    local node = get_node_at_cursor(window)
    return node and node:type()
end

--- Get the text from a range in the current buffer.
---@param start_row integer # The start row of the range.
---@param start_col integer # The start column of the range.
---@param end_row integer # The end row of the range.
---@param end_col integer # The end column of the range.
---@return string # The text in the range.
function M.text(window, start_row, start_col, end_row, end_col)
    window = window or vim.api.nvim_get_current_win()

    if start_row > end_row then
        start_row, start_col, end_row, end_col = end_row, end_col, start_row, start_col
    elseif start_row == end_row and start_col > end_col then
        start_col, end_col = end_col, start_col
    end

    local buffer = vim.api.nvim_win_get_buf(window)
    local lines = vim.api.nvim_buf_get_text(buffer, start_row - 1, start_col - 1, end_row - 1, end_col, {})

    return table.concat(lines, '\n')
end

--- Gets the lines in the given range.
---@param window integer|nil # the window to get the lines from. 0 or nil for the current window
---@param start_row integer|nil # the start row of the range. 0 or nil for the current row
---@param end_row integer|nil # the end row of the range. 0 or nil for the current row
---@return string[] # the lines in the range
function M.lines(window, start_row, end_row)
    window = window or vim.api.nvim_get_current_win()
    start_row = start_row or vim.api.nvim_win_get_cursor(window)[1]
    end_row = end_row or start_row

    if start_row > end_row then
        start_row, end_row = end_row, start_row
    end

    local buffer = vim.api.nvim_win_get_buf(window)
    local lines = vim.api.nvim_buf_get_lines(buffer, start_row - 1, end_row or start_row, false)

    return lines
end

--- Gets the current selection or the current word if there is no selection
---@param window integer|nil # the window to get the selection from. 0 or nil for the current window
---@param smart boolean|nil # whether to use the current word if there is no selection
---@return string|nil # the current selection or the current word
function M.current_selection(window, smart)
    smart = smart == nil and true or false

    local mode = vim.fn.mode()
    local res

    if mode == 'v' or mode == 'V' or mode == '' then
        local _, v_row, v_col = unpack(vim.fn.getpos 'v')
        local _, c_row, c_col = unpack(vim.fn.getpos '.')

        res = M.text(window, v_row, v_col, c_row, c_col)
    else
        local _, s_row, s_col = vim.fn.getpos "'<"
        local _, e_row, e_col = vim.fn.getpos "'>"

        if s_row and s_col and e_row and e_col then
            res = M.text(window, s_row, s_col, e_row, e_col)
        elseif smart then
            res = vim.fn.expand '<cword>'
        end
    end

    return res ~= '' and res or nil
end

return M

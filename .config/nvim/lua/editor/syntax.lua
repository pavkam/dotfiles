---@class editor.syntax
local M = {}

--- Get the tree for the given buffer.
---@param buffer number|nil # The buffer to get the tree for. 0 or nil for the current buffer.
---@return TSNode|nil # The root node of the tree.
local function get_tree(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local ok, parser = pcall(vim.treesitter.get_parser, buffer, vim.bo.filetype)
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

return M

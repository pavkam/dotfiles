---@class editor.syntax
local M = {}

---@class (exact) editor.syntax.NodeLookupOpts # The options for the node lookup.
---@field window integer|nil # the window to get the cursor position from. 0 or nil for the current window.
---@field buffer integer|nil # the buffer to get the node from. 0, for current buffer, nil for buffer in window.
---@field ignore_injections boolean|nil # whether to include injected languages or not.
---@field ignore_indent boolean|nil # whether to ignore the indentation or not.
---@field lang string|nil # the language to get the node at the cursor for.

--- Get the node under the cursor.
---@param opts editor.syntax.NodeLookupOpts|nil # the options for the node lookup.
---@return TSNode|nil, integer # the node or nil if not found; and the buffer number.
function M.node(opts)
    opts = opts or {}
    opts.window = opts.window or vim.api.nvim_get_current_win()

    if opts.buffer == 0 then
        opts.buffer = vim.api.nvim_get_current_buf()
    elseif opts.buffer == nil then
        opts.buffer = vim.api.nvim_win_get_buf(opts.window)
    end

    if not vim.api.nvim_buf_is_valid(opts.buffer) then
        return nil, 0
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(opts.window))

    if vim.api.nvim_get_mode().mode == 'i' then
        col = col - 1
    end

    if opts and opts.ignore_indent then
        local line = M.lines(row, row, { buffer = opts.buffer })[1]
        local indent = line:match '^%s*()'

        -- set position to the first non white-space character
        if indent and col < indent - 1 then
            col = indent - 1
        end
    else
        row = row - 1
    end

    local ok, node = pcall(vim.treesitter.get_node, {
        bufnr = opts.buffer,
        lang = opts and opts.lang,
        ignore_injections = opts and opts.ignore_injections, -- include injected languages
        pos = { row, col },
    })

    return (ok and node or nil), opts.buffer
end

--- Replace the targeted node with the given text.
---@param replacement string|nil # the text to replace the node with.
---@param opts editor.syntax.NodeLookupOpts|nil # the options for the node lookup.
function M.replace_node(replacement, opts)
    local node, buffer = M.node(opts)

    if node then
        local start_row, start_col, end_row, end_col = node:range()
        vim.api.nvim_buf_set_text(buffer, start_row, start_col, end_row, end_col, { replacement })
    end
end

---@alias editor.syntax.NodeCategory
---| 'comment'
---| 'identifier'
---| 'jsx'

local comment_node_types = { 'comment', 'comment_block', 'Comment' }
local identifier_node_types = { 'identifier', 'property_identifier', 'type_identifier', 'field_identifier' }
local string_content_node_types = { 'string_content', 'string_fragment' }
local string_node_types = { 'string', 'interpreted_string_literal' }

--- Gets the category of the targeted node.
---@param opts editor.syntax.NodeLookupOpts|nil # the options for the node lookup.
---@return editor.syntax.NodeCategory|nil # the category of the node.
function M.node_category(opts)
    local node = M.node(opts)
    if not node then
        return nil
    end

    if node:type():match '^jsx_' ~= nil then
        return 'jsx'
    end

    if vim.list_contains(identifier_node_types, node:type()) then
        return 'identifier'
    end

    if node:type() == 'source' then
        node = node:parent()
    end

    if node and vim.list_contains(comment_node_types, node:type()) then
        return 'comment'
    end

    return nil
end

--- Get the targeted node's text.
---@param opts editor.syntax.NodeLookupOpts|nil # the options for the node lookup.
---@return string # the text of the node.
function M.node_text(opts)
    local node, buffer = M.node(opts)

    if node and vim.list_contains(string_content_node_types, node:type()) then
        node = node:parent()
    end

    if node and vim.list_contains(string_node_types, node:type()) then
        local start_row, start_col, end_row, end_col = node:range()
        return M.text(start_row + 1, start_col + 1, end_row + 1, end_col, { buffer = buffer })
    end

    return vim.fn.expand '<cword>'
end

---@class (exact) editor.syntax.TextOpts
---@field buffer integer|nil # the buffer to get the text from. 0 or nil for the current buffer.

--- Get the text from a range in the current buffer.
---@param start_row integer # the start row of the range.
---@param start_col integer # the start column of the range.
---@param end_row integer # the end row of the range.
---@param end_col integer # the end column of the range.
---@param opts editor.syntax.TextOpts|nil # the options for the text.
---@return string # The text in the range.
function M.text(start_row, start_col, end_row, end_col, opts)
    opts = opts or {}
    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()

    if start_row > end_row then
        start_row, start_col, end_row, end_col = end_row, end_col, start_row, start_col
    elseif start_row == end_row and start_col > end_col then
        start_col, end_col = end_col, start_col
    end

    local lines = vim.api.nvim_buf_get_text(opts.buffer, start_row - 1, start_col - 1, end_row - 1, end_col, {})

    return table.concat(lines, '\n')
end

--- Gets the lines in the given range.
---@param start_row integer # the start row of the range.
---@param end_row integer # the end row of the range.
---@param opts editor.syntax.TextOpts|nil # the options for the text.
---@return string[] # the lines in the range
function M.lines(start_row, end_row, opts)
    opts = opts or {}
    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()

    if start_row > end_row then
        start_row, end_row = end_row, start_row
    end

    return vim.api.nvim_buf_get_lines(opts.buffer, start_row - 1, end_row or start_row, false)
end

---@class (exact) editor.syntax.CurrentLineTextOpts
---@field window integer|nil # the window to get the line from. 0 or nil for the current window

--- Gets the current line.
---@param opts editor.syntax.CurrentLineTextOpts|nil # the options for the current line.
---@return string # the current line text
function M.current_line_text(opts)
    opts = opts or {}
    opts.window = opts.window or vim.api.nvim_get_current_win()

    local row = vim.api.nvim_win_get_cursor(opts.window)[1]
    return M.lines(row, row, { buffer = vim.api.nvim_win_get_buf(opts.window) })[1]
end

---@class (exact) editor.syntax.CurrentSelectedTextOpts
---@field window integer|nil # the window to get the selection from. 0 or nil for the current window
---@field smart boolean|nil # whether to use the current word if there is no selection

--- Gets the current selection or the current word if there is no selection
---@param opts editor.syntax.CurrentSelectedTextOpts|nil # the options for the selection.
---@return string|nil # the current selection or the current word
function M.selected_text(opts)
    opts = opts or {}
    if opts.smart ~= false then
        opts.smart = true
    end

    local mode = vim.fn.mode()
    local res

    if mode == 'v' or mode == 'V' or mode == '' then
        local _, v_row, v_col = unpack(vim.fn.getpos 'v')
        local _, c_row, c_col = unpack(vim.fn.getpos '.')

        res = M.text(v_row, v_col, c_row, c_col)
    else
        local _, s_row, s_col = vim.fn.getpos "'<"
        local _, e_row, e_col = vim.fn.getpos "'>"

        if s_row and s_col and e_row and e_col then
            res = M.text(s_row, s_col, e_row, e_col)
        elseif opts.smart then
            res = M.node_text { window = opts.window }
        end
    end

    return res ~= '' and res or nil
end

--- Increment the number or boolean for the targeted node.
---@param value number # the value to increment by.
---@param opts editor.syntax.NodeLookupOpts|nil # the options for the node lookup.
---@return boolean # whether the value was modified.
function M.increment_node(value, opts)
    local node, buffer = M.node(opts)

    ---@type number|boolean|nil
    local v
    if node then
        local start_row, start_col, end_row, end_col = node:range()
        local str = M.text(start_row + 1, start_col + 1, end_row + 1, end_col, { buffer = buffer })

        if node:type() == 'number' then
            v = tonumber(str)
        elseif node:type() == 'true' then
            v = true
        elseif node:type() == 'false' then
            v = false
        end
    end

    if type(v) == 'boolean' then
        local vv = (v and 1 or 0) + value

        if vv > 0 then
            if vim.bo.filetype == 'python' then
                M.replace_node('True', opts)
            else
                M.replace_node('true', opts)
            end
        else
            if vim.bo.filetype == 'python' then
                M.replace_node('False', opts)
            else
                M.replace_node('false', opts)
            end
        end

        return true
    elseif type(v) == 'number' then
        M.replace_node(tostring(v + value), opts)
        return true
    end

    return false
end

---@class (exact) editor.syntax.RenameExprOpts # The options for the rename expression.
---@field whole_word boolean|nil # whether to match the whole word or not.
---@field orig string|nil # the original text to replace if not supplied, uses the '<C-r><C-w>' command keys.
---@field new string|nil # the new text to replace with (if not supplied, uses the orig).

--- Creates a rename expression that can be fed to vim.
---@param opts editor.syntax.RenameExprOpts|nil # The options for the rename expression.
function M.create_rename_expression(opts)
    opts = opts or {}
    assert(type(opts) == 'table')

    local orig = opts.orig or '<C-r><C-w>'
    local new = opts.new or orig

    assert(type(orig) == 'string')
    assert(type(new) == 'string')

    if opts.whole_word then
        orig = '\\<' .. orig .. '\\>'
    end

    return ':<C-u>%s/\\V' .. orig .. '/' .. new .. '/gI<Left><Left><Left>'
end

return M

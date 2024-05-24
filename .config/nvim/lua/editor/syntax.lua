---@class editor.syntax
local M = {}

---@class editor.syntax.GetNodeAtCursorOpts
---@field ignore_injections? boolean # Whether to include injected languages or not.
---@field ignore_indent? boolean # Whether to ignore the indentation or not.
---@field lang? string # The language to get the node at the cursor for.

--- Get the node at the cursor.
---@param window number|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param opts? editor.syntax.GetNodeAtCursorOpts # The options for the node at the cursor.
---@return TSNode|nil # The node at the cursor.
local function get_node_at_cursor(window, opts)
    window = window or vim.api.nvim_get_current_win()

    local buffer = vim.api.nvim_win_get_buf(window)
    if not vim.api.nvim_buf_is_valid(buffer) then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(window)

    if opts and opts.ignore_indent then
        local line = M.current_line(window)
        local indent = line:match '^%s*()'

        -- set position to the first non whitespace character
        if indent and cursor[2] < indent - 1 then
            cursor[2] = indent - 1
        end
    else
        cursor[1] = cursor[1] - 1
    end

    local ok, node = pcall(vim.treesitter.get_node, {
        bufnr = buffer,
        lang = opts and opts.lang,
        ignore_injections = opts and opts.ignore_injections, -- include injected languages
        pos = cursor,
    })

    return ok and node or nil
end

--- Get the node under the cursor.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param opts? editor.syntax.GetNodeAtCursorOpts # The options for the node under the cursor.
---@return TSNode|nil # The node under the cursor.
function M.node_under_cursor(window, opts)
    local node = get_node_at_cursor(window, opts)
    return node
end

--- Get the type of the node under the cursor.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param opts? editor.syntax.GetNodeAtCursorOpts # The options for the node under the cursor.
---@return string|nil # The type of the node under the cursor.
function M.node_type_under_cursor(window, opts)
    local node = get_node_at_cursor(window, opts)
    return node and node:type()
end

--- Get the node text under the cursor respecting syntactic boundaries.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param opts? editor.syntax.GetNodeAtCursorOpts # The options for the node text under the cursor.
---@param replacement string|nil # The text to replace the node with.
function M.replace_node_under_cursor(window, replacement, opts)
    window = window or vim.api.nvim_get_current_win()
    local node = get_node_at_cursor(window, opts)

    if node then
        local start_row, start_col, end_row, end_col = node:range()
        local buffer = vim.api.nvim_win_get_buf(window)

        vim.api.nvim_buf_set_text(buffer, start_row, start_col, end_row, end_col, { replacement })
    end
end

--- Get the node text under the cursor respecting syntactic boundaries.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param opts? editor.syntax.GetNodeAtCursorOpts # The options for the node text under the cursor.
---@return string # The text under the cursor.
function M.node_text_under_cursor(window, opts)
    local node = get_node_at_cursor(window, opts)
    if node then
        if node:type() == 'string_fragment' then
            node = node:parent()
        end

        if node and node:type() == 'string' then
            local start_row, start_col, end_row, end_col = node:range()
            return M.text(window, start_row + 1, start_col + 1, end_row + 1, end_col)
        end
    end

    return vim.fn.expand '<cword>'
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

--- Gets the current line.
---@param window integer|nil # the window to get the line from. 0 or nil for the current window
function M.current_line(window)
    window = window or vim.api.nvim_get_current_win()

    local row = vim.api.nvim_win_get_cursor(window)[1]
    return M.lines(window, row, row)[1]
end

--- Gets the current selection or the current word if there is no selection
---@param window integer|nil # the window to get the selection from. 0 or nil for the current window
---@param smart boolean|nil # whether to use the current word if there is no selection
---@return string|nil # the current selection or the current word
function M.current_selection(window, smart)
    if smart ~= false then
        smart = true
    end

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
            res = M.node_text_under_cursor(window)
        end
    end

    return res ~= '' and res or nil
end

--- Increment the number or boolean under the cursor.
---@param window integer|nil # The window to get the cursor position from. 0 or nil for the current window.
---@param value number # The value to increment by.
---@return boolean # Whether the value was modified
function M.increment_node_under_cursor(window, value)
    local node = get_node_at_cursor(window)

    ---@type number|boolean|nil
    local v
    if node then
        local start_row, start_col, end_row, end_col = node:range()
        local str = M.text(window, start_row + 1, start_col + 1, end_row + 1, end_col)

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
                M.replace_node_under_cursor(window, 'True')
            else
                M.replace_node_under_cursor(window, 'true')
            end
        else
            if vim.bo.filetype == 'python' then
                M.replace_node_under_cursor(window, 'False')
            else
                M.replace_node_under_cursor(window, 'false')
            end
        end

        return true
    elseif type(v) == 'number' then
        M.replace_node_under_cursor(window, tostring(v + value))
        return true
    end

    return false
end

---@class editor.syntax.RenameOpts
---@field whole_word? boolean # Whether to match the whole word or not.
---@field orig? string # The original text to replace if not supplied, uses the '<C-r><C-w>' command keys.
---@field new? string # The new text to replace with (if not supplied, uses the orig).

--- Creates a rename expression that can be fed to vim.
---@param opts? editor.syntax.RenameOpts # The options for the rename expression.
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

---@class project.highlight-navigation
local M = {}

---@class vim.lsp.Position # A position in a text document expressed as zero-based line and character offset.
---@field line integer # Line position in a document (zero-based).
---@field character integer # Character offset on a line in a document (zero-based).

---@class vim.lsp.Range # Represents a range in a text document expressed as (zero-based) start and end positions.
---@field start vim.lsp.Position # The range's start position.
---@field ["end"] vim.lsp.Position # The range's end position.

---@class vim.lsp.DocumentHighlightItem # Represents a document highlight, like a symbol kind, a range and a parent.
---@field kind number string # The highlight kind, such as a symbol kind.
---@field range vim.lsp.Range # The range this highlight applies to.

---@class vim.lsp.DocumentHighlightResponse # Represents a document highlight response.
---@field error lsp.ResponseError|nil # Error message
---@field result vim.lsp.DocumentHighlightItem[] # The highlight items.

---@alias vim.lsp.ClientDocumentHighlightResponse table<integer, vim.lsp.DocumentHighlightResponse>

-- TODO: ""Failed to get document highlights: "timeout"

--- Jumps to the next of previous occurrence of the highlighted token.
---@param window integer|nil # The window to jump in
---@param forward boolean # Whether to jump to the next or previous occurrence
---@return boolean # Whether the jump was successful or not
local function jump(window, forward)
    assert(type(forward) == 'boolean')

    window = window or vim.api.nvim_get_current_win()
    local buffer = vim.api.nvim_win_get_buf(window)

    local attached = vim.lsp.get_clients { bufnr = buffer }
    if not attached or #attached == 0 then
        return false
    end

    ---@type vim.lsp.ClientDocumentHighlightResponse|nil, string|nil
    local reply, err = vim.lsp.buf_request_sync(
        buffer,
        vim.lsp.protocol.Methods.textDocument_documentHighlight,
        vim.lsp.util.make_position_params(),
        100
    )

    -- get the first element of the table
    local first_response = reply and next(reply) and reply[next(reply)]

    if err or first_response and first_response.error then
        ide.tui.warn(
            string.format(
                'Failed to get document highlights: %s',
                vim.inspect(err or first_response and first_response.error.message)
            )
        )

        return false
    end

    if (first_response == nil) or (first_response.result == nil) then
        return false
    end

    ---@cast first_response vim.lsp.DocumentHighlightResponse

    -- get the highlight ranges
    local highlights = vim.iter(first_response.result)
        :map(function(highlight)
            return highlight.range
        end)
        :totable()

    -- Sort in order. Which means that we need to find the current highlight in the list the one before or after are our
    -- target.
    table.sort(highlights, function(a, b)
        return (a.start.line < b.start.line) or (a.start.line == b.start.line and a.start.character < b.start.character)
    end)

    local current_line, current_col = unpack(vim.api.nvim_win_get_cursor(window))
    current_line = current_line - 1

    ---@type vim.lsp.Range|nil
    local target
    for i, range in ipairs(highlights) do
        if
            range.start.line == current_line
            and (range.start.character <= current_col and range['end'].character >= current_col)
        then
            if forward then
                if i == #highlights then
                    target = highlights[1]
                else
                    target = highlights[i + 1]
                end
            else
                if i == 1 then
                    target = highlights[#highlights]
                else
                    target = highlights[i - 1]
                end
            end
        end
    end

    if target then
        vim.api.nvim_win_set_cursor(window, { target.start.line + 1, target.start.character })
        return true
    end

    return false
end

--- Jumps to the previous occurrence of the highlighted token.
---@param window integer|nil # The window to jump in
---@return boolean # Whether the jump was successful or not
function M.next(window)
    return jump(window, true)
end

--- Jumps to the previous occurrence of the highlighted token.
---@param window integer|nil # The window to jump in
---@return boolean # Whether the jump was successful or not
function M.prev(window)
    return jump(window, false)
end

return M

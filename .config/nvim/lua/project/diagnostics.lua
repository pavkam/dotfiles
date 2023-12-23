---@class project.diagnostics
local M = {}

--- Checks if there is a diagnostic at the current position
---@param row integer # the row to check
---@param buffer integer|nil # the buffer to check, or 0 or nil for the current buffer
---@return Diagnostic[] # whether there is a diagnostic at the current position
function M.for_position(buffer, row)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local diagnostics = vim.diagnostic.get(buffer)
    if #diagnostics == 0 then
        return {}
    end

    local matching = vim.tbl_filter(function(d)
        --[[@cast d Diagnostic]]
        return d.lnum <= row and d.end_lnum >= row
    end, diagnostics)

    ---@cast matching Diagnostic[]
    return matching
end

--- Checks if there is a diagnostic at the current position
---@param window integer|nil # the window to check, or 0 or nil for the current window
---@return Diagnostic[] # whether there is a diagnostic at the current position
function M.for_current_position(window)
    window = window or vim.api.nvim_get_current_win()
    local buffer = vim.api.nvim_win_get_buf(window)

    local row = vim.api.nvim_win_get_cursor(window)[1]

    return M.for_position(buffer, row - 1)
end

--- Jump to the next or previous diagnostic
---@param next_or_prev boolean # whether to jump to the next or previous diagnostic
---@param severity "ERROR"|"WARN"|"INFO"|"HINT"|nil # the severity to jump to, or nil for all
function M.jump(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    local sev = severity and vim.diagnostic.severity[severity] or nil
    go { severity = sev }
end

return M

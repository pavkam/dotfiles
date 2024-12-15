local diagnostics = require 'diagnostics'
local lsp = require 'lsp'

--- Shows the hover popup
local function hover()
    if package.loaded['ufo'] then
        local winid = require('ufo').peekFoldedLinesUnderCursor()
        if winid then
            return
        end
    end

    local ft = vim.bo.filetype

    if vim.tbl_contains({ 'vim', 'help' }, ft) then
        vim.cmd('silent! h ' .. vim.fn.expand '<cword>')
    elseif #diagnostics.for_current_position() > 0 then
        vim.diagnostic.open_float()
    elseif lsp.buffer_has_capability(0, 'hover') then
        vim.lsp.buf.hover()
    else
        ide.tui.info 'No hover information available!'
    end
end

return hover

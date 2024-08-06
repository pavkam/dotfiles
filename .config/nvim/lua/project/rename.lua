local qf = require 'ui.qf'

--- Handles the result of a rename request
---@param result any # the result of the request
local function handle_post_rename(result)
    if not result then
        return
    end

    local notification, entries = 'Following changes have been made:', {}

    local function add_entry(uri, edits)
        -- extend notification
        local file_name = vim.fn.fnamemodify(vim.uri_to_fname(uri), ':.')

        if #notification > 0 then
            notification = notification .. '\n'
        end
        notification = notification .. string.format('- **%d** in *%s*', #edits, file_name)

        -- populate QF list
        local buffer = vim.uri_to_bufnr(uri)

        vim.fn.bufload(buffer)

        for _, edit in ipairs(edits) do
            table.insert(entries, {
                buffer = buffer,
                lnum = edit.range.start.line + 1,
                col = edit.range.start.character + 1,
            })
        end
    end

    -- scan results
    if result.documentChanges then
        for _, entry in ipairs(result.documentChanges) do
            if entry.edits then
                add_entry(entry.textDocument.uri, entry.edits)
            end
        end
    elseif result.changes then
        for uri, edits in pairs(result.changes) do
            add_entry(uri, edits)
        end
    end

    -- notify and fill QF
    vim.info(notification)
    if #entries > 0 then
        qf.add_items('c', entries)
    end
end

--- Handles a rename request
---@param ... any # the arguments passed to the handler
return function(...)
    local result = select(2, ...)
    local ctx = select(3, ...)

    handle_post_rename(result)

    vim.lsp.handlers[ctx.method](...)
end

local utils = require "utils"

local function handle_post_rename(result)
    if not result then
        return
    end

    local notification, entries = 'Following changes have been made:', {}

    local function add_entry(uri, edits)
        -- extend notification
        local file_name = vim.fn.fnamemodify(vim.uri_to_fname(uri)  , ":.")

        if #notification > 0 then
            notification = notification .. '\n'
        end
        notification = notification .. string.format('- **%d** in *%s*', #edits, file_name)

        -- populate QF list
        local buffer = vim.uri_to_bufnr(uri)
        vim.fn.bufload(buffer)

        print("buffer", buffer)

        for _, edit in ipairs(edits) do
            local start_line = edit.range.start.line + 1
            local line = vim.api.nvim_buf_get_lines(buffer, start_line - 1, start_line, false)[1]

            table.insert(entries, {
                filename = file_name,
                buffer = buffer,
                lnum = start_line,
                col = edit.range.start.character + 1,
                text = line
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
        changes = result.changes

        for uri, edits in pairs(changes) do
            add_entry(uri, edits)
        end
    end

    -- notify and fill QF
    utils.info(notification)

    if #entries > 0 then
        vim.fn.setqflist(entries, "a")
        vim.cmd("copen")
    end
end

return function(...)
    local result = select(2, ...)
    local ctx = select(3, ...)

    handle_post_rename(result)
    vim.lsp.handlers[ctx.method](...)
end


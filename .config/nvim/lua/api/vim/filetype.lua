local pinned_file_type_buffers = {}

--- Returns the list of pinned file types
---@return string[] # the list of pinned file types
function vim.filetype.pinned()
    return vim.tbl_keys(pinned_file_type_buffers)
end

--- Pins a buffer of a given file type to its current window
---@param file_type string|string[] # the file type to pin
function vim.filetype.pin_to_window(file_type)
    if type(file_type) == 'table' and vim.islist(file_type) then
        for _, ft in ipairs(file_type) do
            vim.filetype.pin_to_window(ft)
        end

        return
    end

    assert(type(file_type) == 'string' and file_type ~= '')

    pinned_file_type_buffers[file_type] = true

    -- search all windows, their shown buffer and pin if necessary
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buffer = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_get_option_value('filetype', { buf = buffer }) == file_type then
            vim.wo[win].winfixbuf = true
        end
    end
end

vim.api.nvim_create_autocmd('FileType', {
    callback = function(evt)
        local win = vim.api.nvim_get_current_win()

        if pinned_file_type_buffers[vim.api.nvim_get_option_value('filetype', { buf = evt.buf })] then
            vim.wo[win].winfixbuf = true
        end
    end,
})

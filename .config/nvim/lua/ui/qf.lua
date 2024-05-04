local utils = require 'core.utils'

---@class ui.qf`
local M = {}

---@class ui.qf.HandleRef
---@field id integer
---@field window? integer

---@alias ui.qf.Handle ui.qf.HandleRef | 'c' | 'l'
---@alias ui.qf.Property 'changedtick' | 'context' | 'efm' | 'id' | 'idx' | 'items' |  'lines' | 'nr' | 'qfbufnr' | 'size' | 'title' | 'winid' | 'all'

--- Gets the details of the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param what? ui.qf.Property[] # the details to get
---@return { window?: integer, id: integer }|table|nil # the list details, or nil if there is no list
local function list_details(handle, what)
    assert(not what or vim.tbl_islist(what))

    if handle == 'c' then
        handle = { id = 0 }
    elseif handle == 'l' then
        handle = { id = 0, window = vim.api.nvim_get_current_win() }
    end

    ---@cast handle ui.qf.HandleRef

    assert(handle and type(handle.id) == 'number')

    local query = { id = handle.id }
    for _, k in ipairs(what or {}) do
        query[k] = 0
    end

    local tbl = handle.window and vim.fn.getloclist(handle.window, query) or vim.fn.getqflist(query)
    return vim.tbl_isempty(tbl) and nil or vim.tbl_extend('force', tbl, { window = handle.window })
end

--- Gets the type of the current quick-fix or locations list
---@param window integer|nil # the window to check, or 0 or nil for the current window
---@return ui.qf.HandleRef|nil # the list handle, or nil if there is no list
local function focused_list(window)
    window = window or vim.api.nvim_get_current_win()
    local info = vim.fn.getwininfo(window)[1]

    if info.quickfix == 0 then
        return nil
    end

    local details = info.loclist == 0 and vim.fn.getqflist { id = 0, idx = 0 } or vim.fn.getloclist(window, { id = 0, idx = 0 })

    return {
        id = details.id,
        window = info.loclist ~= 0 and window or nil,
    }
end

--- Gets the index of the current quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@return integer|nil # the index of the current item, or nil if there is no list
function M.current_index(handle)
    local details = list_details(handle, { 'idx' })
    return details and details.idx or nil
end

--- Deletes the item at the given index from the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param index integer # the index of the item to delete
---@return integer # the number of items remaining in the list
function M.delete_at(handle, index)
    local list = assert(list_details(handle, { 'items' }))

    if #list.items >= index then
        table.remove(list.items, index)

        if package.loaded['bqf'] then
            require('bqf').hidePreviewWindow()
        end

        if not list.window then
            vim.fn.setqflist({}, 'r', { id = list.id, items = list.items })
        else
            vim.fn.setloclist(list.window, {}, 'r', { id = list.id, items = list.items })
        end
    end

    return #list.items
end

--- Remove file from a given list
---@param handle ui.qf.Handle # the list handle
---@param file string # the file to remove
function M.delete_file(handle, file)
    assert(type(file) == 'string' and file ~= '')

    local list = assert(list_details(handle, { 'items' }))
    list.items = vim.tbl_filter(function(item)
        return item.filename ~= file
    end, list.items)

    if not list.window then
        vim.fn.setqflist({}, 'r', { id = list.id, items = list.items })
    else
        vim.fn.setloclist(list.window, {}, 'r', { id = list.id, items = list.items })
    end
end

--- Toggles the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param open boolean # whether to open the list window
function M.toggle(handle, open)
    local list = assert(list_details(handle))

    if not list.window then
        vim.cmd('silent! ' .. (open and 'copen' or 'cclose'))
    else
        vim.api.nvim_win_call(list.window, function()
            vim.cmd('silent! ' .. (open and 'lopen' or 'lclose'))
        end)
    end

    if package.loaded['bqf'] and not open then
        require('bqf').hidePreviewWindow()
    end

    if not open then
        vim.cmd.wincmd 'p'
    end
end

--- Clears the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
function M.clear(handle)
    local list = assert(list_details(handle))

    if not list.window then
        vim.fn.setqflist({}, 'r', { id = list.id, items = {} })
    else
        vim.fn.setloclist(list.window, {}, 'r', { id = list.id, items = {} })
    end
end

--- Adds the given position to the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param items { lnum: integer, col: integer, buffer: integer }[] # the items
---@param replace? boolean # whether to replace the current list
function M.add_items(handle, items, replace)
    assert(vim.tbl_islist(items))
    local list = assert(list_details(handle))

    local entries = {}
    for _, item in ipairs(items) do
        local line = vim.api.nvim_buf_get_lines(item.buffer, item.lnum - 1, item.lnum, false)[1]
        if not line or line == '' then
            line = '<empty>'
        end

        table.insert(entries, {
            bufnr = item.buffer,
            lnum = item.lnum,
            col = item.col,
            text = line,
            filename = vim.api.nvim_buf_get_name(item.buffer),
        })
    end

    local op = replace and 'r' or 'a'
    if list.window then
        vim.fn.setloclist(list.window, {}, op, { id = list.id, items = entries })
    else
        vim.fn.setqflist({}, op, { id = list.id, items = entries })
    end

    M.toggle(handle, true)
end

--- Adds the current position to the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param window integer|nil # the window to add the item to, or 0 or nil for the current window
---@param replace? boolean # whether to replace the current list
function M.add_at_cursor(handle, window, replace)
    local list = assert(list_details(handle))
    window = window or vim.api.nvim_get_current_win()

    local r, c = unpack(vim.api.nvim_win_get_cursor(window))

    utils.info(string.format('Added position **%d:%d** to %s list.', r, c, list.window and 'locations' or 'quick-fix'))

    M.add_items(handle, {
        {
            buffer = vim.api.nvim_win_get_buf(window),
            lnum = r,
            col = c + 1,
        },
    }, replace)
end

--- Gets the handles of all quick-fix lists
---@return ui.qf.HandleRef[]
function M.lists()
    local last = vim.fn.getqflist { idx = '$' }

    if not last.idx or last.idx == 0 then
        return {}
    end

    ---@type ui.qf.HandleRef[]
    local lists = {}
    for i = 1, last.idx do
        local list = vim.fn.getqflist { idx = i, id = 0 }
        table.insert(lists, { id = list.id })
    end

    return lists
end

--- Gets the handles of all locations lists
---@param window integer|nil # the window to check, or 0 or nil for the current window
---@return ui.qf.HandleRef[]
function M.loc_lists(window)
    window = window or vim.api.nvim_get_current_win()
    local last = vim.fn.getloclist(window, { idx = '$' })

    if not last.idx or last.idx == 0 then
        return {}
    end

    ---@type ui.qf.HandleRef[]
    local lists = {}
    for i = 1, last.idx do
        local list = vim.fn.getloclist(window, { idx = i, id = 0 })
        table.insert(lists, { id = list.id, window = window })
    end

    return lists
end

--- Forget file from all lists
---@param file string # the file to forget
function M.forget(file)
    assert(type(file) == 'string' and file ~= '')

    --- remove the file from the quickfix lists
    for _, handle in ipairs(M.lists()) do
        M.delete_file(handle, file)
    end

    --- remove the file from the location lists of all the windows
    for _, tab_page in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab_page)) do
            if vim.api.nvim_win_is_valid(win) then
                for _, handle in ipairs(M.loc_lists(win)) do
                    M.delete_file(handle, file)
                end
            end
        end
    end
end

-- quick-fix and locations list
vim.keymap.set('n', '<leader>qc', function()
    M.clear 'c'
    M.toggle('c', false)
end, { desc = 'Clear quick-fix list' })

vim.keymap.set('n', '<leader>qC', function()
    M.clear 'l'
    M.toggle('l', false)
end, { desc = 'Clear locations list' })

vim.keymap.set('n', '<leader>qq', function()
    M.toggle('c', true)
end, { desc = 'Show quick-fix list' })

vim.keymap.set('n', '<leader>ql', function()
    M.toggle('l', true)
end, { desc = 'Show locations list' })

vim.keymap.set('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quick-fix item' })
vim.keymap.set('n', '[q', '<cmd>cprev<cr>', { desc = 'Previous quick-fix item' })

vim.keymap.set('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location item' })
vim.keymap.set('n', '[l', '<cmd>lprev<cr>', { desc = 'Previous location item' })

utils.attach_keymaps('qf', function(set)
    set('n', 'x', function()
        local handle = assert(focused_list())
        local window = vim.api.nvim_get_current_win()

        local r, c = unpack(vim.api.nvim_win_get_cursor(window))
        local remaining = M.delete_at(handle, r)

        r = math.min(r, remaining)
        if r > 0 then
            vim.api.nvim_win_set_cursor(window, { r, c })
        end

        if remaining == 0 then
            M.toggle(handle, false)
        end
    end, { desc = 'Remove item' })

    set('n', '<del>', 'x', { desc = 'Remove item', remap = true })
    set('n', '<bs>', 'x', { desc = 'Remove item', remap = true })

    set('n', 'X', function()
        local handle = assert(focused_list())

        M.clear(handle)
        M.toggle(handle, false)
    end, { desc = 'Clear all' })
end, true)

utils.attach_keymaps(nil, function(set)
    set('n', '<leader>qa', function()
        M.add_at_cursor 'c'
    end, { desc = 'Add quick-fix item' })

    set('n', '<leader>qA', function()
        M.add_at_cursor 'l'
    end, { desc = 'Add location item' })
end)

return M

local icons = require 'icons'
local keys = require 'keys'

ide.ft['qf'].pinned_to_window = true

---@class ui.qf`
local M = {}

---@class vim.QuickFixListItem # Quick-fix list item.
---@field bufnr number # number of buffer that has the file name.
---@field module string # module name.
---@field lnum number # line number in the buffer (first line is 1).
---@field end_lnum number # end of line number if the item is multi-line.
---@field col number # column number (first column is 1).
---@field end_col number # end of column number if the item has range.
---@field vcol boolean # |TRUE|: "col" is visual column |FALSE|: "col" is byte index.
---@field nr number # error number.
---@field pattern string # search pattern used to locate the error.
---@field text string # description of the error.
---@field type string # type of the error, 'E', '1', etc.
---@field valid boolean # |TRUE|: recognized error message.
---@field user_data any # custom data associated with the item, can be any type.

---@class vim.QuickFixList # Quick-fix list.
---@field changedtick number # total number of changes made to the list.
---@field context string # quick-fix list context.
---@field id number # quick-fix list ID. If not present, set to 0.
---@field idx number # index of the quick-fix entry in the list. If not present, set to 0.
---@field items vim.QuickFixListItem[] # quick-fix list entries. If not present, set to an empty list.
---@field nr number # quick-fix list number. If not present, set to 0.
---@field qfbufnr number # number of the buffer displayed in the quick-fix window. If not present, set to 0.
---@field size number # number of entries in the quick-fix list. If not present, set to 0.
---@field title string # quick-fix list title text. If not present, set to "".
---@field winid number # quick-fix window ID. If not present, set to 0.

---@alias ui.qf.Type # The type of the quick-fix or locations list.
---| 'c' # quick-fix list.
---| 'l' # locations list.

---@class ui.qf.HandleRef # The handle of the quick-fix or locations list.
---@field id integer # the list ID.
---@field window integer|nil # the window the list is associated with (for location lists)

---@alias ui.qf.Handle ui.qf.HandleRef | ui.qf.Type # The handle of the quick-fix or locations list.

---@class ui.qf.QuickFixList : vim.QuickFixList # Extended quick-fix list
---@field window integer|nil # the window the list is associated with (for location lists)

--- Gets the details of the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@return ui.qf.QuickFixList|nil # the list details, or nil if there is no list
local function list_details(handle)
    if handle == 'c' then
        handle = { id = 0 }
    elseif handle == 'l' then
        handle = { id = 0, window = vim.api.nvim_get_current_win() }
    end

    ---@cast handle ui.qf.HandleRef

    assert(handle and type(handle.id) == 'number')

    local query = { id = handle.id, all = 1 }

    ---@type vim.QuickFixList
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

    ---@type vim.QuickFixList
    local details = info.loclist == 0 and vim.fn.getqflist { id = 0, idx = 0 }
        or vim.fn.getloclist(window, { id = 0, idx = 0 })

    return {
        id = details.id,
        window = info.loclist ~= 0 and window or nil,
    }
end

--- Gets the index of the current quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@return integer|nil # the index of the current item, or nil if there is no list
function M.current_index(handle)
    local details = list_details(handle)
    return details and details.idx or nil
end

--- Deletes the item at the given index from the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param index integer # the index of the item to delete
---@return integer # the number of items remaining in the list
function M.delete_at(handle, index)
    local list = assert(list_details(handle))

    if #list.items >= index then
        table.remove(list.items, index)

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

    local list = assert(list_details(handle))
    list.items = vim.iter(list.items)
        :filter(function(item)
            return item.filename ~= file
        end)
        :totable()

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
end

--- Checks whether the quick-fix or locations list is visible
---@return boolean # whether the list is visible
function M.visible()
    return #vim.iter(vim.fn.getwininfo())
        :filter(function(win)
            return win.quickfix == 1 and win.loclist == 0
        end)
        :totable() == 1
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

---@class ui.qf.AddOpts # The options for adding items to the quick-fix or locations list
---@field replace boolean|nil # whether to replace or append to the current list
---@field title string|nil # the title of the list if creating a new one

--- Adds the given position to the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param items { lnum: integer, col: integer, buffer: integer }[] # the items
---@param opts ui.qf.AddOpts|nil # the options
function M.add_items(handle, items, opts)
    assert(vim.islist(items))

    opts = opts or {}
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

    local op = opts.replace and 'r' or 'a'
    if list.window then
        vim.fn.setloclist(list.window, {}, op, { id = list.id, items = entries, title = opts.title })
    else
        vim.fn.setqflist({}, op, { id = list.id, items = entries, title = opts.title })
    end

    M.toggle(handle, true)
end

--- Adds the current position to the quick-fix or locations list
---@param handle ui.qf.Handle # the list handle
---@param window integer|nil # the window to add the item to, or 0 or nil for the current window
---@param opts ui.qf.AddOpts|nil # the options
function M.add_at_cursor(handle, window, opts)
    local list = assert(list_details(handle))

    window = window or vim.api.nvim_get_current_win()

    local r, c = unpack(vim.api.nvim_win_get_cursor(window))

    ide.tui.info(
        string.format('Added position **%d:%d** to %s list.', r, c, list.window and 'locations' or 'quick-fix')
    )

    M.add_items(handle, {
        {
            buffer = vim.api.nvim_win_get_buf(window),
            lnum = r,
            col = c + 1,
        },
    }, opts)

    -- switch back to the original window
    vim.cmd.wincmd 'p'
end

--- Gets the handles of all quick-fix lists
---@return ui.qf.HandleRef[]
function M.lists()
    ---@type ui.qf.HandleRef[]
    local lists = {}
    for i = 1, 10 do
        local list = vim.fn.getqflist { nr = i, id = 0 }
        if not list.id or list.id == 0 then
            break
        end

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

--- Gets the details of the focused list.
---@param window integer|nil # the window to check, or 0 or nil for the current window.
---@return ui.qf.QuickFixList|nil, ui.qf.Type|nil # the list details and the type (or `nil`)
function M.details(window)
    local list = focused_list(window)
    if not list then
        return nil, nil
    end

    local details = list_details(list)
    if not details then
        return nil, nil
    end

    return details, details.window and 'l' or 'c'
end

--- Forget file from all lists
---@param file string # the file to forget
function M.forget(file)
    assert(type(file) == 'string' and file ~= '')

    --- remove the file from the quick-fix lists
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

---@class ui.qf.ExportedQuickFixListItem # Quick-fix list item
---@field file string # file name
---@field module string # module name
---@field lnum number # line number in the buffer (first line is 1)
---@field end_lnum number # end of line number if the item is multi-line
---@field col number # column number (first column is 1)
---@field end_col number # end of column number if the item has range
---@field nr number # error number
---@field pattern string # search pattern used to locate the error
---@field text string # description of the error
---@field type string # type of the error, 'E', '1', etc.
---@field user_data any # custom data associated with the item, can be any type.

---@class ui.qf.ExportedQuickFixList # Quick-fix list
---@field context string # quick-fix list context
---@field idx number # index of the quick-fix entry in the list. If not present, set to 0.
---@field items vim.QuickFixListItem[] # quick-fix list entries. If not present, set to an empty list.
---@field title string # quick-fix list title text. If not present, set to ""

---@class ui.qf.Exported
---@field quick_fix vim.QuickFixList[]

--- Exports the quick-fix data
---@return ui.qf.Exported
function M.export()
    ---@type ui.qf.ExportedQuickFixList[]
    local lists = {}

    for _, handle in ipairs(M.lists()) do
        local list = list_details(handle)
        if list then
            table.insert(lists, {
                context = list.context,
                idx = list.idx,
                items = vim.iter(list.items)
                    :map(
                        ---@param i vim.QuickFixListItem
                        ---@return ui.qf.ExportedQuickFixListItem
                        function(i)
                            return {
                                file = vim.api.nvim_buf_get_name(i.bufnr),
                                module = i.module,
                                lnum = i.lnum,
                                end_lnum = i.end_lnum,
                                col = i.col,
                                end_col = i.end_col,
                                nr = i.nr,
                                pattern = i.pattern,
                                text = i.text,
                                type = i.type,
                                user_data = i.user_data,
                            }
                        end
                    )
                    :totable(),
                title = list.title,
            })
        end
    end

    return {
        quick_fix = lists,
    }
end

--- Imports the quick-fix data
---@param data ui.qf.Exported
function M.import(data)
    assert(type(data) == 'table' and type(data.quick_fix) == 'table')

    for _, list in ipairs(data.quick_fix) do
        vim.fn.setqflist({}, ' ', {
            context = list.context,
            idx = list.idx,
            items = vim.iter(list.items)
                :map(
                    ---@param i ui.qf.ExportedQuickFixListItem
                    ---@return vim.QuickFixListItem
                    function(i)
                        if vim.fn.filereadable(i.file) == 0 then
                            return nil
                        end

                        local buffer = vim.fn.bufadd(i.file)
                        if buffer == 0 then
                            return nil
                        end

                        return {
                            bufnr = buffer,
                            module = i.module,
                            lnum = i.lnum,
                            end_lnum = i.end_lnum,
                            col = i.col,
                            end_col = i.end_col,
                            nr = i.nr,
                            pattern = i.pattern,
                            text = i.text,
                            type = i.type,
                            user_data = i.user_data,
                        }
                    end
                )
                :filter(function(i)
                    return i ~= nil
                end)
                :totable(),
            title = list.title,
        })
    end
end

-- quick-fix and locations list
keys.map('n', '<leader>qc', function()
    M.clear 'c'
    M.toggle('c', false)
end, { desc = 'Clear quick-fix list' })

keys.map('n', '<leader>qC', function()
    M.clear 'l'
    M.toggle('l', false)
end, { desc = 'Clear locations list' })

keys.map('n', '<leader>qq', function()
    M.toggle('c', true)
end, { desc = 'Show quick-fix list' })

keys.map('n', '<leader>ql', function()
    M.toggle('l', true)
end, { desc = 'Show locations list' })

keys.map('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quick-fix item' })
keys.map('n', '[q', '<cmd>cprev<cr>', { desc = 'Previous quick-fix item' })

keys.map('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location item' })
keys.map('n', '[l', '<cmd>lprev<cr>', { desc = 'Previous location item' })

keys.attach('qf', function(set)
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

keys.attach(nil, function(set)
    set('n', '<leader>qa', function()
        M.add_at_cursor('c', nil, { title = '[' .. os.date '%Y-%m-%d %H:%M:%S' .. '] Manual list' })
    end, { desc = 'Add quick-fix item' })

    set('n', '<leader>qA', function()
        M.add_at_cursor 'l'
    end, { desc = 'Add location item' })
end)

keys.group { lhs = '<leader>q', mode = { 'n', 'v' }, icon = icons.UI.Fix, desc = 'Quick-Fix' }

return M

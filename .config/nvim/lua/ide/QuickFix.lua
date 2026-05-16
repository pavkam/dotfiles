-- QuickFix: abstraction over neovim's quickfix and location lists.
-- Wraps vim.fn.getqflist/setqflist into a clean API.

local QuickFix = Class('QuickFix')

function QuickFix:init() end

--- Get the quickfix list items.
---@return table[]
function QuickFix:items()
    return vim.fn.getqflist()
end

--- Set the quickfix list.
---@param items table[] # list of {filename, lnum, col, text} items
---@param opts { title?: string, action?: string }|nil
function QuickFix:set(items, opts)
    opts = opts or {}
    vim.fn.setqflist({}, opts.action or ' ', {
        title = opts.title or 'QuickFix',
        items = items,
    })
end

--- Add items to the quickfix list.
---@param items table[]
function QuickFix:add(items)
    self:set(items, { action = 'a' })
end

--- Clear the quickfix list.
function QuickFix:clear()
    vim.fn.setqflist({}, 'r')
end

--- Open the quickfix window.
function QuickFix:open()
    vim.cmd.copen()
end

--- Close the quickfix window.
function QuickFix:close()
    vim.cmd.cclose()
end

--- Toggle the quickfix window.
function QuickFix:toggle()
    local wins = vim.fn.getqflist({ winid = 0 })
    if wins.winid ~= 0 then
        self:close()
    else
        self:open()
    end
end

--- Jump to the next quickfix entry.
function QuickFix:next()
    pcall(vim.cmd.cnext)
end

--- Jump to the previous quickfix entry.
function QuickFix:prev()
    pcall(vim.cmd.cprev)
end

--- Count of quickfix items.
---@return integer
function QuickFix:count()
    return #self:items()
end

--- Populate from diagnostics.
---@param opts { bufnr?: integer, severity?: integer }|nil
function QuickFix:from_diagnostics(opts)
    vim.diagnostic.setqflist(opts)
end

--- Get the location list for a window.
---@param winid integer|nil # window id (0 or nil for current)
---@return table[]
function QuickFix:loclist(winid)
    return vim.fn.getloclist(winid or 0)
end

--- Set the location list for a window.
---@param winid integer|nil
---@param items table[]
---@param opts { title?: string }|nil
function QuickFix:set_loclist(winid, items, opts)
    opts = opts or {}
    vim.fn.setloclist(winid or 0, {}, ' ', {
        title = opts.title or 'Location List',
        items = items,
    })
end

--- Get details of a quickfix/location list by handle type.
---@param handle 'c'|'l' # 'c' for quickfix, 'l' for location list
---@return { id: integer, items: table[], window: integer|nil }|nil
function QuickFix:_list_details(handle)
    if handle == 'c' then
        local d = vim.fn.getqflist({ id = 0, idx = 0, items = 1 })
        return d.id ~= 0 and { id = d.id, items = d.items, window = nil } or nil
    else
        local win = vim.api.nvim_get_current_win()
        local d = vim.fn.getloclist(win, { id = 0, idx = 0, items = 1 })
        return d.id ~= 0 and { id = d.id, items = d.items, window = win } or nil
    end
end

--- Clear a quickfix or location list.
---@param handle 'c'|'l'
function QuickFix:clear_list(handle)
    local list = self:_list_details(handle)
    if not list then return end
    if list.window then
        vim.fn.setloclist(list.window, {}, 'r', { id = list.id, items = {} })
    else
        vim.fn.setqflist({}, 'r', { id = list.id, items = {} })
    end
end

--- Toggle a quickfix or location list window.
---@param handle 'c'|'l'
---@param open boolean
function QuickFix:toggle_list(handle, open)
    if handle == 'c' then
        vim.cmd('silent! ' .. (open and 'copen' or 'cclose'))
    else
        local list = self:_list_details(handle)
        if list and list.window then
            vim.api.nvim_win_call(list.window, function()
                vim.cmd('silent! ' .. (open and 'lopen' or 'lclose'))
            end)
        else
            vim.cmd('silent! ' .. (open and 'lopen' or 'lclose'))
        end
    end
end

--- Get the focused list type from the current window.
---@return 'c'|'l'|nil
function QuickFix:focused_list()
    local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    if info.quickfix == 0 then return nil end
    return info.loclist == 0 and 'c' or 'l'
end

--- Delete an item at a given index from a list.
---@param handle 'c'|'l'
---@param index integer
---@return integer # remaining item count
function QuickFix:delete_at(handle, index)
    local list = self:_list_details(handle)
    if not list then return 0 end
    if index >= 1 and index <= #list.items then
        table.remove(list.items, index)
        if list.window then
            vim.fn.setloclist(list.window, {}, 'r', { id = list.id, items = list.items })
        else
            vim.fn.setqflist({}, 'r', { id = list.id, items = list.items })
        end
    end
    return #list.items
end

--- Add the cursor position to a quickfix or location list.
---@param handle 'c'|'l'
---@param win_id? integer
---@param opts? { title?: string }
function QuickFix:add_at_cursor(handle, win_id, opts)
    opts = opts or {}
    win_id = win_id or vim.api.nvim_get_current_win()
    local r, c = unpack(vim.api.nvim_win_get_cursor(win_id))
    local bufnr = vim.api.nvim_win_get_buf(win_id)
    local line = vim.api.nvim_buf_get_lines(bufnr, r - 1, r, false)[1] or '<empty>'
    local entry = { bufnr = bufnr, lnum = r, col = c + 1, text = line,
        filename = vim.api.nvim_buf_get_name(bufnr) }

    local list = self:_list_details(handle) or { id = 0 }
    if list.window then
        vim.fn.setloclist(list.window, {}, 'a', { id = list.id, items = { entry }, title = opts.title })
    else
        vim.fn.setqflist({}, 'a', { id = list.id, items = { entry }, title = opts.title })
    end
    self:toggle_list(handle, true)
    vim.cmd.wincmd('p')
end

--- Remove a file from all quickfix and location lists.
---@param file string
function QuickFix:forget(file)
    for i = 1, 10 do
        local d = vim.fn.getqflist({ nr = i, id = 0, items = 1 })
        if not d.id or d.id == 0 then break end
        local filtered = vim.tbl_filter(function(item)
            local item_file = item.filename
            if (not item_file or item_file == '') and item.bufnr and item.bufnr > 0 then
                item_file = vim.api.nvim_buf_is_valid(item.bufnr) and vim.api.nvim_buf_get_name(item.bufnr) or ''
            end
            return item_file ~= file
        end, d.items)
        if #filtered ~= #d.items then
            vim.fn.setqflist({}, 'r', { id = d.id, items = filtered })
        end
    end
end

---@return string
function QuickFix:__tostring()
    return string.format('QuickFix(%d items)', self:count())
end

return QuickFix

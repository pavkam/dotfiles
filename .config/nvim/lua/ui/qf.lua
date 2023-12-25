local utils = require 'core.utils'

---@alias ui.qf.Type 'c'|'l'

local M = {}

--- Gets the type of the current quick-fix or locations list
---@param window integer|nil # the window to check, or 0 or nil for the current window
---@return ui.qf.Type|nil
function M.active_qf_type(window)
    window = window or vim.api.nvim_get_current_win()
    local info = vim.fn.getwininfo(window)[1]

    local qftype
    if info.quickfix == 0 then
        qftype = nil
    elseif info.loclist == 0 then
        qftype = 'c'
    else
        qftype = 'l'
    end

    return qftype
end

--- Gets the index of the current quick-fix or locations list
---@param qf_type ui.qf.Type # the type of the list
---@return integer|nil
function M.current_index(qf_type)
    assert(qf_type == 'c' or qf_type == 'l')

    local details = qf_type == 'c' and vim.fn.getqflist { id = 0, idx = 0 } or vim.fn.getloclist(0, { id = 0, idx = 0 })
    return details.idx
end

--- Deletes the item at the given index from the quick-fix or locations list
---@param qf_type ui.qf.Type # the type of the list
---@param index integer # the index of the item to delete
---@return integer # the number of items remaining in the list
function M.delete_item(qf_type, index)
    assert(qf_type == 'c' or qf_type == 'l')

    if package.loaded['bqf'] then
        require('bqf').hidePreviewWindow()
    end

    local list = qf_type == 'c' and vim.fn.getqflist() or vim.fn.getloclist(0)
    table.remove(list, index)

    if qf_type == 'c' then
        vim.fn.setqflist(list)
    else
        vim.fn.setloclist(0, list)
    end

    return #list
end

-- quick-fix and locations list
vim.keymap.set('n', '<leader>qm', function()
    vim.diagnostic.setqflist { open = true }
end, { desc = 'Diagnostics to quck-fix list' })
vim.keymap.set('n', '<leader>qm', function()
    vim.diagnostic.setloclist { open = true }
end, { desc = 'Diagnostics to locations list' })
vim.keymap.set('n', '<leader>qc', function()
    vim.fn.setqflist({}, 'r')
end, { desc = 'Clear quick-fix list' })
vim.keymap.set('n', '<leader>qC', function()
    vim.fn.setloclist(0, {})
end, { desc = 'Clear locations list' })
vim.keymap.set('n', '<leader>qq', '<cmd>copen<cr>', { desc = 'Show quick-fix list' })
vim.keymap.set('n', '<leader>ql', '<cmd>lopen<cr>', { desc = 'Show locations list' })
vim.keymap.set('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quick-fix item' })
vim.keymap.set('n', '[q', '<cmd>cprev<cr>', { desc = 'Previous quick-fix item' })
vim.keymap.set('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location item' })
vim.keymap.set('n', '[l', '<cmd>lprev<cr>', { desc = 'Previous location item' })

utils.attach_keymaps('qf', function(set)
    set('n', 'dd', function()
        local qf_type = M.active_qf_type()
        assert(qf_type)

        local r, c = unpack(vim.api.nvim_win_get_cursor(0))
        local remaining = M.delete_item(qf_type, r)

        r = math.min(r, remaining)
        if r > 0 then
            vim.api.nvim_win_set_cursor(0, { r, c })
        end

        if remaining == 0 then
            vim.cmd(qf_type .. 'close')
        end
    end, { desc = 'Remove item' })

    set('n', '<del>', 'dd', { desc = 'Remove item', remap = true })
    set('n', '<bs>', 'dd', { desc = 'Remove item', remap = true })
end, true)

utils.attach_keymaps(nil, function(set)
    ---@param qftype 'c'|'l'
    local function add_line(qftype)
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        if not line or line == '' then
            line = '<empty>'
        end

        utils.info(string.format('Added position **%d:%d** to %s list.', r, c, qftype == 'l' and 'locations' or 'quick-fix'))

        local entry = {
            bufnr = vim.api.nvim_get_current_buf(),
            lnum = r,
            col = c,
            text = line,
        }

        if qftype == 'l' then
            vim.fn.setloclist(0, { entry }, 'a')
        else
            vim.fn.setqflist({ entry }, 'a')
        end

        vim.api.nvim_command(qftype == 'c' and 'copen' or 'lopen')
        vim.api.nvim_command 'wincmd p'
    end

    set('n', '<leader>qa', function()
        add_line 'c'
    end, { desc = 'Add quick-fix item' })

    set('n', '<leader>qA', function()
        add_line 'l'
    end, { desc = 'Add location item' })
end)

return M

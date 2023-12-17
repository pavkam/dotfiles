local utils = require 'core.utils'

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
        if package.loaded['bqf'] then
            require('bqf').hidePreviewWindow()
        end

        local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
        local qftype
        if info.quickfix == 0 then
            qftype = nil
        elseif info.loclist == 0 then
            qftype = 'c'
        else
            qftype = 'l'
        end

        local list = qftype == 'l' and vim.fn.getloclist(0) or vim.fn.getqflist()
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))

        table.remove(list, r)

        if qftype == 'l' then
            vim.fn.setloclist(0, list)
        else
            vim.fn.setqflist(list)
        end

        r = math.min(r, #list)
        if r > 0 then
            vim.api.nvim_win_set_cursor(0, { r, c })
        end

        if #list == 0 then
            vim.cmd(qftype .. 'close')
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

-- Quickfix keymaps extension: quickfix/location list navigation and management.

local Extension = require 'ide.Extension'
local Window = require 'ide.Window'

local QuickfixKeymaps = Class('QuickfixKeymaps', Extension)

function QuickfixKeymaps:init()
    Extension.init(self, 'QuickfixKeymaps')
end

function QuickfixKeymaps:on_register(ctx)
    local qf = IDE.quickfix

    if IDE.keys and IDE.keys.group then
        IDE.keys:group('<leader>q', { desc = 'Quick-Fix', mode = { 'n', 'v' } })
    end

    ctx:keymap('n', '<leader>qc', function()
        qf:clear_list('c')
        qf:toggle_list('c', false)
    end, { desc = 'Clear quickfix' })

    ctx:keymap('n', '<leader>qC', function()
        qf:clear_list('l')
        qf:toggle_list('l', false)
    end, { desc = 'Clear locations' })

    ctx:keymap('n', '<leader>qq', function()
        qf:toggle_list('c', true)
    end, { desc = 'Toggle quickfix' })

    ctx:keymap('n', '<leader>ql', function()
        qf:toggle_list('l', true)
    end, { desc = 'Toggle locations' })

    ctx:keymap('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quickfix' })
    ctx:keymap('n', '[q', '<cmd>cprev<cr>', { desc = 'Prev quickfix' })
    ctx:keymap('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location' })
    ctx:keymap('n', '[l', '<cmd>lprev<cr>', { desc = 'Prev location' })

    ctx:keymap('n', '<leader>qa', function()
        qf:add_at_cursor('c', nil, { title = '[' .. os.date('%Y-%m-%d %H:%M:%S') .. '] Manual list' })
    end, { desc = 'Add quickfix item' })

    ctx:keymap('n', '<leader>qA', function()
        qf:add_at_cursor('l')
    end, { desc = 'Add location item' })

    ctx:hook('FileType', function(evt)
        if not require('ide.Buffer').is_valid(evt.buf) then return end
        ctx:keymap('n', 'x', function()
            local handle = qf:focused_list() or 'c'
            local pos = Window.current():cursor()
            local remaining = qf:delete_at(handle, pos.row)
            if remaining == 0 then qf:toggle_list(handle, false) end
        end, { buffer = evt.buf, desc = 'Remove item' })

        ctx:keymap('n', '<Del>', 'x', { buffer = evt.buf })
        ctx:keymap('n', '<BS>', 'x', { buffer = evt.buf })

        ctx:keymap('n', 'X', function()
            local handle = qf:focused_list() or 'c'
            qf:clear_list(handle)
            qf:toggle_list(handle, false)
        end, { buffer = evt.buf, desc = 'Clear all' })

        -- History navigation in native quickfix window
        ctx:keymap('n', '<', function()
            pcall(vim.cmd, 'colder')
        end, { buffer = evt.buf, desc = 'Older quickfix list' })

        ctx:keymap('n', '>', function()
            pcall(vim.cmd, 'cnewer')
        end, { buffer = evt.buf, desc = 'Newer quickfix list' })
    end, { pattern = 'qf', desc = 'QF buffer keymaps' })
end

return QuickfixKeymaps

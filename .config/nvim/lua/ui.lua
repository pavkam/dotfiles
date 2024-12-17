local events = require 'events'
local keys = require 'keys'
local git = require 'git'
local icons = require 'icons'
local progress = require 'progress'

require 'marks'
require 'qf'
require 'tmux'
require 'file-palette'
require 'mouse'

ide.ft['help'].pinned_to_window = true
ide.ft['query'].pinned_to_window = true
ide.ft['markdown'].wrap_enabled = true
ide.ft['gitcommit'].wrap_enabled = true
ide.ft['gitrebase'].wrap_enabled = true
ide.ft['hgcommit'].wrap_enabled = true

keys.group { lhs = 'g', mode = { 'n', 'v' }, icon = icons.UI.Next, desc = 'Go-to' }
keys.group { lhs = ']', mode = { 'n', 'v' }, icon = icons.UI.Next, desc = 'Next' }
keys.group { lhs = '[', mode = { 'n', 'v' }, icon = icons.UI.Prev, desc = 'Previous' }

-- Disable some sequences
keys.map({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
keys.map('n', '<BS>', '<Nop>', { silent = true })
keys.map('n', '<M-v>', '<cmd>wincmd v<CR>', { desc = 'Split window below' })
keys.map('n', '<M-h>', '<cmd>wincmd s<CR>', { desc = 'Split window right' })

-- Better jump list navigation
keys.map('n', ']]', '<C-i>', { desc = 'Next location' })
keys.map('n', '[[', '<C-o>', { desc = 'Previous location' })

-- terminal mappings
keys.map('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter normal mode' })

-- buffer management
keys.map('n', '<leader><leader>', function()
    if not vim.buf.is_special() then
        pcall(vim.cmd.edit, '#')
    end
end, { icon = icons.UI.Switch, desc = 'Switch buffer', silent = true })

keys.map('n', '<leader>c', function()
    ide.buf[vim.api.nvim_get_current_buf()].remove()
end, { icon = icons.UI.Close, desc = 'Close buffer' })
keys.map('n', '<leader>C', function()
    ide.buf[vim.api.nvim_get_current_buf()].remove_others()
end, { icon = icons.UI.Close, desc = 'Close other buffers' })

for i = 1, 9 do
    keys.map('n', '<M-' .. i .. '>', function()
        local buffer = vim.buf.get_listed_buffers({ loaded = false })[i]
        if buffer then
            vim.cmd.buffer(buffer)
        end
    end, { desc = 'Go to buffer ' .. i })
end

keys.map('n', '<leader>w', '<cmd>w<cr>', { icon = icons.UI.Save, desc = 'Save buffer' })
keys.map('n', '<leader>W', '<cmd>wa<cr>', { icon = icons.UI.SaveAll, desc = 'Save all buffers' })

keys.map('n', '[b', '<cmd>bprevious<cr>', { icon = icons.UI.Next, desc = 'Previous buffer' })
keys.map('n', ']b', '<cmd>bnext<cr>', { icons = icons.UI.Prev, desc = 'Next buffer' })

-- tabs
keys.map('n', ']t', '<cmd>tabnext<cr>', { icon = icons.UI.Next, desc = 'Next tab' })
keys.map('n', '[t', '<cmd>tabprevious<cr>', { icons = icons.UI.Prev, desc = 'Previous tab' })

-- diagnostics
keys.map('n', ']m', function()
    ide.buf.current.next_diagnostic(true)
end, { icon = icons.UI.Next, desc = 'Next Diagnostic' })
keys.map('n', '[m', function()
    ide.buf.current.next_diagnostic(false)
end, { icon = icons.UI.Prev, desc = 'Previous Diagnostic' })
keys.map('n', ']e', function()
    ide.buf.current.next_diagnostic(true, 'ERROR')
end, { icon = icons.UI.Next, desc = 'Next Error' })
keys.map('n', '[e', function()
    ide.buf.current.next_diagnostic(false, 'ERROR')
end, { icon = icons.UI.Prev, desc = 'Previous Error' })
keys.map('n', ']w', function()
    ide.buf.current.next_diagnostic(true, 'WARN')
end, { icon = icons.UI.Next, desc = 'Next Warning' })
keys.map('n', '[w', function()
    ide.buf.current.next_diagnostic(false, 'WARN')
end, { icon = icons.UI.Prev, desc = 'Previous Warning' })

-- Command mode remaps to make my life easier using the keyboard
keys.map('c', '<Down>', function()
    if vim.fn.wildmenumode() then
        return '<C-n>'
    else
        return '<Down>'
    end
end, { expr = true })

keys.map('c', '<Up>', function()
    if vim.fn.wildmenumode() then
        return '<C-p>'
    else
        return '<Up>'
    end
end, { expr = true })

keys.map('c', '<Left>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Left>'
    else
        return '<Left>'
    end
end, { expr = true })

keys.map('c', '<Right>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Right>'
    else
        return '<Right>'
    end
end, { expr = true })

-- Add "q" to special windows
keys.attach(vim.buf.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end)

keys.attach('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
end, true)

keys.attach(nil, function(set)
    keys.group { mode = 'n', icon = icons.UI.AI, lhs = '<leader>x', desc = 'AI' }

    set('n', '<leader>xx', function()
        require('CopilotChat').open()
    end, { desc = 'Open chat window', icon = icons.UI.Tool })

    set('n', '<leader>xa', function()
        require('CopilotChat').select_agent()
    end, { desc = 'Select agent', icon = icons.UI.Tool })

    set('n', '<leader>xm', function()
        require('CopilotChat').select_model()
    end, { desc = 'Select model', icon = icons.UI.Tool })

    set('n', '<leader>xf', function()
        require('CopilotChat').ask('Fix the code in the file', {
            context = '#buffer',
            clear_chat_on_new_prompt = true,
            auto_insert_mode = false,
            window = {
                layout = 'float',
                relative = 'cursor',
                width = 1,
                height = 0.4,
                row = 1,
            },
        })
    end, { desc = 'Chat with AI', icon = icons.UI.AI })
end)

keys.map('n', '<leader>u', require('api.config').manage, { icon = icons.UI.UI, desc = 'Manage options' })

-- Specials using "Command/Super" key (when available!)
keys.map('n', '<M-]>', '<C-i>', { icon = icons.UI.Next, desc = 'Next location' })
keys.map('n', '<M-[>', '<C-o>', { icon = icons.UI.Prev, desc = 'Previous location' })

---@module 'api.buf'
---
-- file detection commands
events.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local buffer = ide.buf[
        evt.buf --[[@as integer]]
    ]

    if buffer and buffer.is_normal then
        local option = ide.config.use('custom_events_triggered', { buffer = buffer, persistent = false })

        -- if custom events have been triggered, bail
        if option.get() or buffer.file_path == '' then
            return
        end

        events.trigger_user_event 'NormalFile'

        git.check_tracked(buffer.file_path, function(yes)
            if yes then
                events.trigger_user_event 'GitFile'
            end
        end)

        option.set(true)
    end
end)

-- resize splits if window got resized
events.on_event('VimResized', function()
    vim.schedule(function()
        ide.tui.redraw()
        events.trigger_status_update_event()
    end)
end)

--- Macro tracking
events.on_event({ 'RecordingEnter' }, function()
    ide.tui.info(
        string.format(
            'Started recording macro into register `%s`',
            vim.fn.reg_recording(),
            { prefix_icon = icons.UI.Macro, suffix_icon = icons.TUI.Ellipsis }
        )
    )

    progress.update('recording_macro', {
        fn = function()
            return vim.fn.reg_recording() ~= ''
        end,
        desc = 'Recording macro',
        ctx = vim.fn.reg_recording(),
        timeout = math.huge,
    })
end)

events.on_event({ 'RecordingLeave' }, function()
    ide.tui.info(
        string.format(
            'Stopped recording macro into register `%s`',
            vim.fn.reg_recording(),
            { prefix_icon = icons.UI.Checkmark, suffix_icon = icons.TUI.Ellipsis }
        )
    )

    progress.stop 'recording_macro'
end)

---@class ui
local M = {}

local ignore_hidden_files_option = ide.config.register_toggle('ignore_hidden_files', function(enabled)
    if package.loaded['neo-tree'] then
        -- Update neo-tree state
        local mgr = require 'neo-tree.sources.manager'
        mgr.get_state('filesystem').filtered_items.visible = not enabled
    end
end, { icon = icons.UI.ShowHidden, desc = 'Ignore hidden files', scope = 'global' })

M.ignore_hidden_files = {
    --- Returns whether hidden files are ignored or not
    ---@return boolean # true if hidden files are ignored, false otherwise
    active = ignore_hidden_files_option.get,
    --- Toggles ignoring of hidden files on or off
    ---@param value boolean|nil # if nil, it will toggle the current value, otherwise it will set the value
    toggle = function(value)
        ignore_hidden_files_option.set(value)
    end,
}

ide.config.register_toggle('treesitter_enabled', function(enabled, buffer)
    assert(buffer)

    if not enabled then
        vim.treesitter.stop(buffer.id)
    else
        vim.treesitter.start(buffer.id)
    end
end, { icon = icons.UI.SyntaxTree, desc = 'Treesitter', scope = { 'buffer' } })

return M

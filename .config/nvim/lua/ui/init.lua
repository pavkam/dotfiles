local utils = require 'core.utils'
local buffers = require 'core.buffers'
local events = require 'core.events'
local keys = require 'core.keys'
local settings = require 'core.settings'
local git = require 'git'
local diagnostics = require 'project.diagnostics'
local icons = require 'ui.icons'
local progress = require 'ui.progress'

require 'ui.hl'
require 'ui.marks'
require 'ui.qf'
require 'ui.tmux'
require 'ui.file-palette'
require 'ui.command-palette'

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
    if not buffers.is_special_buffer() then
        pcall(vim.cmd.edit, '#')
    end
end, { icon = icons.UI.Switch, desc = 'Switch buffer', silent = true })

keys.map('n', '<leader>c', buffers.remove_buffer, { icon = icons.UI.Close, desc = 'Close buffer' })
keys.map('n', '<leader>C', buffers.remove_other_buffers, { icon = icons.UI.Close, desc = 'Close other buffers' })

for i = 1, 9 do
    keys.map('n', '<M-' .. i .. '>', function()
        local buffer = buffers.get_buffer_by_index(i)
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
    diagnostics.jump(true)
end, { icon = icons.UI.Next, desc = 'Next Diagnostic' })
keys.map('n', '[m', function()
    diagnostics.jump(false)
end, { icon = icons.UI.Prev, desc = 'Previous Diagnostic' })
keys.map('n', ']e', function()
    diagnostics.jump(true, 'ERROR')
end, { icon = icons.UI.Next, desc = 'Next Error' })
keys.map('n', '[e', function()
    diagnostics.jump(false, 'ERROR')
end, { icon = icons.UI.Prev, desc = 'Previous Error' })
keys.map('n', ']w', function()
    diagnostics.jump(true, 'WARN')
end, { icon = icons.UI.Next, desc = 'Next Warning' })
keys.map('n', '[w', function()
    diagnostics.jump(false, 'WARN')
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
keys.attach(buffers.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end)

keys.attach('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
end, true)

-- Specials using "Command/Super" key (when available!)
keys.map('n', '<M-]>', '<C-i>', { icon = icons.UI.Next, desc = 'Next location' })
keys.map('n', '<M-[>', '<C-o>', { icon = icons.UI.Prev, desc = 'Previous location' })

-- Fix telescope modified buffers when closing window
events.on_event({ 'BufModifiedSet' }, function(evt)
    if vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'TelescopePrompt' then
        vim.api.nvim_set_option_value('modified', false, { buf = evt.buf })
    end
end)

-- configure special buffers
-- TODO: find other buffers which are funky, extract this functionality
-- into a helper function `vim.pin_buffer(file_type)`
events.on_event({ 'BufWinEnter' }, function(evt)
    local fixed_buffers = { 'qf' }
    local win = vim.api.nvim_get_current_win()

    if vim.tbl_contains(fixed_buffers, vim.api.nvim_get_option_value('filetype', { buf = evt.buf })) then
        vim.wo[win].winfixbuf = true
    end
end)

events.on_event('FileType', function(evt)
    if buffers.is_special_buffer(evt.buf) then
        vim.bo[evt.buf].buflisted = false
    elseif
        buffers.is_transient_buffer(evt.buf)
        or vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'markdown'
    then
        vim.opt_local.wrap = true
    end
end)

-- file detection commands
events.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local current_file = vim.api.nvim_buf_get_name(evt.buf)

    -- if custom events have been triggered, bail
    if settings.get('custom_events_triggered', { buffer = evt.buf, scope = 'instance' }) then
        return
    end

    if not buffers.is_special_buffer(evt.buf) then
        events.trigger_user_event 'NormalFile'

        git.check_tracked(vim.uv.fs_realpath(current_file) or current_file, function(yes)
            if yes then
                events.trigger_user_event 'GitFile'
            end
        end)
    end

    -- do not retrigger these events if the file name is set
    if current_file ~= '' then
        settings.set('custom_events_triggered', true, { buffer = evt.buf, scope = 'instance' })
    end
end)

-- resize splits if window got resized
events.on_event('VimResized', function()
    vim.schedule(function()
        vim.refresh_ui()
        events.trigger_status_update_event()
    end)
end)

--- Macro tracking
events.on_event({ 'RecordingEnter' }, function()
    vim.info(
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
    vim.info(
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

local ignore_hidden_files_setting_name = 'ignore_hidden_files'

---@class ui.hidden_files
M.ignore_hidden_files = {}

--- Returns whether hidden files are ignored or not
---@return boolean # true if hidden files are ignored, false otherwise
function M.ignore_hidden_files.active()
    return settings.get_toggle(ignore_hidden_files_setting_name)
end

--- Toggles ignoring of hidden files on or off
---@param value boolean|nil # if nil, it will toggle the current value, otherwise it will set the value
function M.ignore_hidden_files.toggle(value)
    settings.set_toggle(ignore_hidden_files_setting_name, nil, value)
end

settings.register_toggle(ignore_hidden_files_setting_name, function(enabled)
    -- Update neo-tree state
    local mgr = require 'neo-tree.sources.manager'
    mgr.get_state('filesystem').filtered_items.visible = not enabled
end, { icon = icons.UI.ShowHidden, name = 'Ignore hidden files', scope = 'global' })

settings.register_toggle('treesitter_enabled', function(enabled, buffer)
    if not enabled then
        vim.treesitter.stop(buffer)
    else
        vim.treesitter.start(buffer)
    end
end, { icon = icons.UI.SyntaxTree, name = 'Treesitter', scope = { 'buffer' } })

return M

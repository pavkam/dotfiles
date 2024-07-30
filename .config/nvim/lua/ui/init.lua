local utils = require 'core.utils'
local keys = require 'core.keys'
local settings = require 'core.settings'
local git = require 'git'
local diagnostics = require 'project.diagnostics'
local icons = require 'ui.icons'
local progress = require 'ui.progress'

-- require 'ui.hl'
-- require 'ui.marks'
-- require 'ui.qf'
-- require 'ui.tmux'
-- require 'ui.file-palette'
-- require 'ui.command-palette'

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
    if not utils.is_special_buffer() then
        pcall(vim.cmd.edit, '#')
    end
end, { icon = icons.UI.Switch, desc = 'Switch buffer', silent = true })

keys.map('n', '<leader>c', utils.remove_buffer, { icon = icons.UI.Close, desc = ' Close buffer' })
keys.map('n', '<leader>C', utils.remove_other_buffers, { icon = icons.UI.Close, desc = 'Close other buffers' })

for i = 1, 9 do
    keys.map('n', '<M-' .. i .. '>', function()
        local buffer = utils.get_buffer_by_index(i)
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
utils.attach_keymaps(utils.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end)

utils.attach_keymaps('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { icon = icons.UI.Close, silent = true })
end, true)

-- Specials using "Command/Super" key (when available!)
keys.map('n', '<M-]>', '<C-i>', { icon = icons.UI.Next, desc = 'Next location' })
keys.map('n', '<M-[>', '<C-o>', { icon = icons.UI.Prev, desc = 'Previous location' })

-- Fix telescope modified buffers when closing window
utils.on_event({ 'BufModifiedSet' }, function(evt)
    if vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'TelescopePrompt' then
        vim.api.nvim_set_option_value('modified', false, { buf = evt.buf })
    end
end)

-- configure special buffers
utils.on_event({ 'BufWinEnter' }, function(evt)
    local ignored_fts = { '', 'neo-tree' }
    local win = vim.api.nvim_get_current_win()

    if
        utils.is_special_buffer(evt.buf)
        and not vim.tbl_contains(ignored_fts, vim.api.nvim_get_option_value('filetype', { buf = evt.buf }))
    then
        vim.wo[win].winfixbuf = true
    end
end)

utils.on_event('FileType', function(evt)
    if utils.is_special_buffer(evt.buf) then
        vim.bo[evt.buf].buflisted = false
    elseif
        utils.is_transient_buffer(evt.buf)
        or vim.api.nvim_get_option_value('filetype', { buf = evt.buf }) == 'markdown'
    then
        vim.opt_local.wrap = true
    end
end)

-- file detection commands
utils.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local current_file = vim.api.nvim_buf_get_name(evt.buf)

    -- if custom events have been triggered, bail
    if settings.get('custom_events_triggered', { buffer = evt.buf, scope = 'instance' }) then
        return
    end

    if not utils.is_special_buffer(evt.buf) then
        utils.trigger_user_event 'NormalFile'

        git.check_tracked(vim.loop.fs_realpath(current_file) or current_file, function(yes)
            if yes then
                utils.trigger_user_event 'GitFile'
            end
        end)
    end

    -- do not retrigger these events if the file name is set
    if current_file ~= '' then
        settings.set('custom_events_triggered', true, { buffer = evt.buf, scope = 'instance' })
    end
end)

-- resize splits if window got resized
utils.on_event('VimResized', function()
    vim.schedule(function()
        utils.refresh_ui()
        utils.trigger_status_update_event()
    end)
end)

--- Macro tracking
utils.on_event({ 'RecordingEnter' }, function()
    utils.info(
        icons.UI.Macro
            .. ' Started recording macro into register `'
            .. vim.fn.reg_recording()
            .. '` '
            .. icons.TUI.Ellipsis
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

utils.on_event({ 'RecordingLeave' }, function()
    utils.info(
        icons.UI.Checkmark
            .. ' Stopped recording macro into register `'
            .. vim.fn.reg_recording()
            .. '` '
            .. icons.TUI.Ellipsis
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
end, { name = icons.UI.ShowHidden .. ' Ignore hidden files', description = 'hiding ignored files', scope = 'global' })

settings.register_toggle('treesitter_enabled', function(enabled, buffer)
    if not enabled then
        vim.treesitter.stop(buffer)
    else
        vim.treesitter.start(buffer)
    end
end, { name = icons.UI.SyntaxTree .. ' Treesitter', description = 'tree-sitter', scope = { 'buffer' } })

---@class ui.Sign # Defines a sign
---@field name string # The name of the sign
---@field text string # The text of the sign
---@field texthl string # The highlight group of the text
---@field priority number # The priority of the sign

--- Returns a list of regular and ext-mark signs sorted by priority (low to high)
---@param buffer number | nil # The buffer to get the signs from or nil for the current buffer
---@param lnum number # The line number to get the signs from
---@return ui.Sign[] # A list of signs
function M.get_ext_marks(buffer, lnum)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local ext_marks = vim.api.nvim_buf_get_extmarks(
        buffer,
        -1,
        { lnum - 1, 0 },
        { lnum - 1, -1 },
        { details = true, type = 'sign' }
    )

    ---@cast ext_marks ui.Sign[]
    ext_marks = vim.iter(ext_marks)
        :map(
            ---@param ext_mark vim.api.keyset.get_extmark_item
            function(ext_mark)
                return {
                    name = ext_mark[4].sign_hl_group or ext_mark[4].sign_name or '',
                    text = ext_mark[4].sign_text,
                    texthl = ext_mark[4].sign_hl_group,
                    priority = ext_mark[4].priority,
                }
            end
        )
        :totable()

    -- Sort by priority
    table.sort(ext_marks, function(a, b)
        return (a.priority or 0) < (b.priority or 0)
    end)

    return ext_marks
end

return M

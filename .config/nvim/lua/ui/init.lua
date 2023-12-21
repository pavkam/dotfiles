local utils = require 'core.utils'
local settings = require 'core.settings'
local git = require 'git'
local toggles = require 'core.toggles'
local diagnostics = require 'project.diagnostics'

-- apply colorscheme first
vim.cmd.colorscheme 'tokyonight'

require 'ui.highlights'
require 'ui.marks'
require 'ui.qf'

-- Disable some sequences
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<BS>', '<Nop>', { silent = true })

-- window navigation
if not utils.has_plugin 'nvim-tmux-navigation' then
    vim.keymap.set('n', '<M-Tab>', '<C-W>w', { desc = 'Switch window' })
    vim.keymap.set('n', '<M-Left>', '<cmd>wincmd h<cr>', { desc = 'Go to left window' })
    vim.keymap.set('n', '<M-Right>', '<cmd>wincmd l<cr>', { desc = 'Go to right window' })
    vim.keymap.set('n', '<M-Down>', '<cmd>wincmd j<cr>', { desc = 'Go to window below' })
    vim.keymap.set('n', '<M-Up>', '<cmd>wincmd k<cr>', { desc = 'Go to window above' })
end

vim.keymap.set('n', '\\', '<C-W>s', { desc = 'Split window below' })
vim.keymap.set('n', '|', '<C-W>v', { desc = 'Split window right' })

-- Better jump list navigation
vim.keymap.set('n', ']]', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '[[', '<C-o>', { desc = 'Previous location' })

-- terminal mappings
vim.keymap.set('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter normal mode' })

-- buffer management
vim.keymap.set('n', '<leader><leader>', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, 'e #')
end, { desc = 'Switch buffer', silent = true })
vim.keymap.set('n', '<leader>bw', '<cmd>w<cr>', { desc = 'Save buffer' })

vim.keymap.set('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- tabs
vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- diagnostics
vim.keymap.set('n', ']m', function()
    diagnostics.jump(true)
end, { desc = 'Next Diagnostic' })
vim.keymap.set('n', '[m', function()
    diagnostics.jump(false)
end, { desc = 'Previous Diagnostic' })
vim.keymap.set('n', ']e', function()
    diagnostics.jump(true, 'ERROR')
end, { desc = 'Next Error' })
vim.keymap.set('n', '[e', function()
    diagnostics.jump(false, 'ERROR')
end, { desc = 'Previous Error' })
vim.keymap.set('n', ']w', function()
    diagnostics.jump(true, 'WARN')
end, { desc = 'Next Warning' })
vim.keymap.set('n', '[w', function()
    diagnostics.jump(false, 'WARN')
end, { desc = 'Previous Warning' })

vim.keymap.set('n', '<leader>uM', function()
    toggles.toggle_diagnostics()
end, { desc = 'Toggle global diagnostics' })

vim.keymap.set('n', '<leader>um', function()
    toggles.toggle_diagnostics { buffer = vim.api.nvim_get_current_buf() }
end, { desc = 'Toggle buffer diagnostics' })

-- Treesitter
vim.keymap.set('n', '<leader>ut', function()
    toggles.toggle_treesitter { buffer = vim.api.nvim_get_current_buf() }
end, { desc = 'Toggle buffer treesitter' })

-- show hidden
if feature_level(1) then
    vim.keymap.set('n', '<leader>uh', function()
        toggles.toggle_ignore_hidden_files()
    end, { desc = 'Toggle show hidden' })
end

-- Command mode remaps to make my life easier using the keyboard
vim.keymap.set('c', '<Down>', function()
    if vim.fn.wildmenumode() then
        return '<C-n>'
    else
        return '<Down>'
    end
end, { expr = true })

vim.keymap.set('c', '<Up>', function()
    if vim.fn.wildmenumode() then
        return '<C-p>'
    else
        return '<Up>'
    end
end, { expr = true })

vim.keymap.set('c', '<Left>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Left>'
    else
        return '<Left>'
    end
end, { expr = true })

vim.keymap.set('c', '<Right>', function()
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
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end, true)

-- Specials using "Command/Super" key (when available!)
vim.keymap.set('n', '<M-]>', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '<M-[>', '<C-o>', { desc = 'Previous location' })
vim.keymap.set('n', '<C-[>', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
vim.keymap.set('n', '<C-]>', '<cmd>bnext<cr>', { desc = 'Next buffer' })

vim.keymap.set('n', '<leader>S', function()
    local select = require('ui.select').advanced
    select { { 'a', 'Super option' }, { 'b', 'Super option 222' }, { 'c', 'Alakhu akbarum falamuisdr' } }
end, { desc = 'Special test' })

-- Exit insert mode when switching buffers
utils.on_event('BufEnter', function(evt)
    local ignored_fts = { 'TelescopePrompt' }

    if vim.fn.mode() == 'i' and vim.tbl_contains(ignored_fts, vim.api.nvim_buf_get_option(evt.buf, 'filetype')) then
        vim.cmd 'stopinsert'
    end
end)

-- pin special buffers into their windows and prevent accidental
-- replacement of them
local just_removed = {}

utils.on_event('BufWinLeave', function(evt)
    local upd = utils.is_special_buffer(evt.buf) and not vim.bo[evt.buf].filetype == 'neo-tree' and evt.buf or nil

    for _, win in ipairs(vim.fn.win_findbuf(evt.buf)) do
        just_removed[win] = upd
    end
end)

utils.on_event({ 'BufWinEnter', 'BufEnter' }, function(evt)
    local win = vim.api.nvim_get_current_win()
    local new_buffer = evt.buf
    local old_buffer = just_removed[win]

    if old_buffer and vim.api.nvim_buf_is_valid(old_buffer) and not utils.is_special_buffer(new_buffer) then
        just_removed[win] = nil
        vim.api.nvim_set_current_buf(old_buffer)
    end
end)

-- configure some special buffers
utils.on_event('FileType', function(evt)
    if utils.is_special_buffer(evt.buf) then
        vim.bo[evt.buf].buflisted = false
    end

    if vim.tbl_contains({ 'gitcommit', 'markdown' }, vim.bo[evt.buf].filetype) then
        vim.opt_local.wrap = true
        vim.opt_local.spell = true
    end
end)

-- file detection commands
utils.on_event({ 'BufReadPost', 'BufNewFile', 'BufWritePost' }, function(evt)
    local current_file = vim.api.nvim_buf_get_name(evt.buf)

    -- if custom events have been triggered, bail
    if settings.get('custom_events_triggered', { buffer = evt.buf }) then
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
        settings.set('custom_events_triggered', true, { buffer = evt.buf })
    end
end)

-- resize splits if window got resized
utils.on_event('VimResized', function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
end)
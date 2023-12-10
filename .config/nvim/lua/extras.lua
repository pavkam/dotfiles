local utils = require 'utils'
local toggles = require 'utils.toggles'

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

-- Some custom mappings for file types
if vim.fn.executable 'jq' then
    utils.attach_keymaps('json', function(set)
        --TODO: use the shell extension
        set('n', '<leader>sJ', ':%!jq .<cr>', { desc = 'Pretty-format JSON' })
    end)
end

-- diagnostics
local function jump_to_diagnostic(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    severity = severity and vim.diagnostic.severity[severity] or nil

    return function()
        go { severity = severity }
    end
end

vim.keymap.set('n', ']m', jump_to_diagnostic(true), { desc = 'Next Diagnostic' })
vim.keymap.set('n', '[m', jump_to_diagnostic(false), { desc = 'Previous Diagnostic' })
vim.keymap.set('n', ']e', jump_to_diagnostic(true, 'ERROR'), { desc = 'Next Error' })
vim.keymap.set('n', '[e', jump_to_diagnostic(false, 'ERROR'), { desc = 'Previous Error' })
vim.keymap.set('n', ']w', jump_to_diagnostic(true, 'WARN'), { desc = 'Next Warning' })
vim.keymap.set('n', '[w', jump_to_diagnostic(false, 'WARN'), { desc = 'Previous Warning' })

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

-- Specials using "Command/Super" key (when available!)
vim.keymap.set('n', '<M-]>', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '<M-[>', '<C-o>', { desc = 'Previous location' })
vim.keymap.set('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
vim.keymap.set('n', '<M-x>', 'dd', { desc = 'Delete line' })
vim.keymap.set('x', '<M-x>', 'd', { desc = 'Delete selection' })

-- misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

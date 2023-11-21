local utils = require 'utils'
local settings = require 'utils.settings'

-- Disable some sequences
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.keymap.set('n', '<BS>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })
vim.keymap.set('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
vim.keymap.set('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })

-- Better normal mode navigation
vim.keymap.set({ 'n', 'x' }, 'gg', function()
    if vim.v.count > 0 then
        vim.cmd('normal! ' .. vim.v.count .. 'gg')
    else
        vim.cmd 'normal! gg0'
    end
end, { desc = 'Start of buffer' })

vim.keymap.set({ 'n', 'x' }, 'G', function()
    vim.cmd 'normal! G$'
end, { desc = 'End of buffer' })

-- move selection up/down
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection downward' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection upward' })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
vim.keymap.set({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
vim.keymap.set('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
vim.keymap.set({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })

-- Better jump list navigation
vim.keymap.set('n', ']]', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '[[', '<C-o>', { desc = 'Previous location' })

-- Add undo break-points
vim.keymap.set('i', ',', ',<c-g>u')
vim.keymap.set('i', '.', '.<c-g>u')
vim.keymap.set('i', ';', ';<c-g>u')

-- Redo
vim.keymap.set('n', 'U', '<C-r>', { desc = 'Redo' })

-- Some editor mappings
vim.keymap.set('i', '<C-BS>', '<C-w>', { desc = 'Delete word' })

vim.keymap.set('i', '<Tab>', function()
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    if c and r then
        local line = vim.api.nvim_buf_get_lines(vim.fn.winbufnr(0), r - 1, r, true)[1]

        local before = string.sub(line, 1, c)
        local after = string.sub(line, c + 1, -1)

        if string.match(before, '^%s*$') ~= nil and string.match(after, '^%s*$') == nil then
            return '<C-t>'
        end
    end

    return '<Tab>'
end, { desc = 'Indent/Tab', expr = true })

vim.keymap.set('i', '<S-Tab>', '<C-d>', { desc = 'Unindent' })
vim.keymap.set('n', '<Tab>', '>>', { desc = 'Indent' })
vim.keymap.set('n', '<S-Tab>', '<<', { desc = 'Indent' })

-- Better page up/down
local function page_expr(dir)
    local jump = vim.api.nvim_win_get_height(0)
    if vim.v.count > 0 then
        jump = jump * vim.v.count
    end

    vim.cmd('normal! ' .. jump .. dir .. 'zz')
end
vim.keymap.set({ 'i', 'n' }, '<PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })
vim.keymap.set({ 'i', 'n' }, '<PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

-- Disable the annoying yank on chnage
vim.keymap.set({ 'n', 'x' }, 'c', [["_c]], { desc = 'Change' })
vim.keymap.set({ 'n', 'x' }, 'C', [["_C]], { desc = 'Change' })
vim.keymap.set('x', 'p', 'P', { desc = 'Paste' })
vim.keymap.set('x', 'P', 'p', { desc = 'Yank & paste' })

-- window navigation
vim.keymap.set('n', '<A-Tab>', '<C-W>w', { desc = 'Switch window' })
vim.keymap.set('n', '<A-Left>', '<cmd>wincmd h<cr>', { desc = 'Go to left window' })
vim.keymap.set('n', '<A-Right>', '<cmd>wincmd l<cr>', { desc = 'Go to right window' })
vim.keymap.set('n', '<A-Down>', '<cmd>wincmd j<cr>', { desc = 'Go to window below' })
vim.keymap.set('n', '<A-Up>', '<cmd>wincmd k<cr>', { desc = 'Go to window above' })
vim.keymap.set('n', '\\', '<C-W>s', { desc = 'Split window below' })
vim.keymap.set('n', '|', '<C-W>v', { desc = 'Split window right' })

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

-- clear search with <esc>
vim.keymap.set({ 'i', 'n' }, '<esc>', '<cmd>nohlsearch<cr><esc>', { desc = 'Escape and clear highlight' })

-- better indenting
vim.keymap.set('x', '<', '<gv', { desc = 'Indent selection' })
vim.keymap.set('x', '>', '>gv', { desc = 'Unindent selection' })

vim.keymap.set('x', '<Tab>', '>gv', { desc = 'Indent selection' })
vim.keymap.set('x', '<S-Tab>', '>gv', { desc = 'Unindent selection' })

-- tabs
vim.keymap.set('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- Some useful keymaps for me
vim.keymap.set('n', 'x', [["_x]], { desc = 'Delete character' })
vim.keymap.set('n', '<Del>', [["_x]], { desc = 'Delete character' })
vim.keymap.set('x', '<BS>', 'd', { desc = 'Delete selection' })

-- Command mode remaps to make my life easier using the keyboard
-- TODO, these remaps should only appear if wildmenu is shown
-- vim.keymap.set('c', '<Down>', '<Right>', { desc = 'Select next item' })
-- vim.keymap.set('c', '<Up>', '<Left>', { desc = 'Select previous item' })
-- vim.keymap.set('c', '<Left>', '<Space><BS><Left>', { desc = 'Left' })
-- vim.keymap.set('c', '<Right>', '<Space><BS><Right>', { desc = 'Right' })

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
    set('n', 'x', function()
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

    set('n', '<del>', 'x', { desc = 'Remove item', remap = true })
    set('n', '<bs>', 'x', { desc = 'Remove item', remap = true })
end, true)

utils.attach_keymaps(nil, function(set)
    set('n', '<leader>qa', function()
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        if not line or line == '' then
            line = '<empty>'
        end

        utils.info(string.format('Added position **%d:%d** to quick-fix list.', r, c))

        vim.fn.setqflist({
            {
                bufnr = vim.api.nvim_get_current_buf(),
                lnum = r,
                col = c,
                text = line,
            },
        }, 'a')

        vim.api.nvim_command 'copen'
        vim.api.nvim_command 'wincmd p'
    end, { desc = 'Add quick-fix item' })

    set('n', '<leader>qA', function()
        local r, c = unpack(vim.api.nvim_win_get_cursor(0))
        local line = vim.api.nvim_get_current_line()
        if not line or line == '' then
            line = '<empty>'
        end

        utils.info(string.format('Added position **%d:%d** to locations list.', r, c))
        vim.fn.setloclist(0, {
            {
                bufnr = vim.api.nvim_get_current_buf(),
                lnum = r,
                col = c,
                text = line,
            },
        }, 'a')

        vim.api.nvim_command 'lopen'
        vim.api.nvim_command 'wincmd p'
    end, { desc = 'Add location item' })
end)

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

local diagnostics_setting_name = 'diagnostics_enabled'
vim.keymap.set('n', '<leader>uM', function()
    local enabled = settings.toggle_global(diagnostics_setting_name, 'diagnostics')
    if not enabled then
        vim.diagnostic.disable()
    else
        vim.diagnostic.enable()
    end
end, { desc = 'Toggle global diagnostics' })

vim.keymap.set('n', '<leader>um', function()
    local buffer = vim.api.nvim_get_current_buf()

    local enabled = settings.toggle_for_buffer(buffer, 'diagnostics_enabled', 'diagnostics')
    if not enabled then
        vim.diagnostic.disable(buffer)
    else
        vim.diagnostic.enable(buffer)
    end
end, { desc = 'Toggle buffer diagnostics' })

-- Treesitter
vim.keymap.set('n', '<leader>ut', function()
    local buffer = vim.api.nvim_get_current_buf()

    local enabled = settings.toggle_for_buffer(buffer, 'treesitter_enabled', 'treesitter')
    if not enabled then
        vim.treesitter.stop(buffer)
    else
        vim.treesitter.start(buffer)
    end
end, { desc = 'Toggle buffer treesitter' })

-- Add "q" to special windows
utils.attach_keymaps(utils.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
end)

utils.attach_keymaps('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
end, true)

-- Some custom mappings for file types
if vim.fn.executable 'jq' then
    utils.attach_keymaps('json', function(set)
        set('n', '<leader>sJ', ':%!jq .<cr>', { desc = 'Pretty-format JSON' })
    end)
end

-- Specials using "Command/Super" key (when available!)
vim.keymap.set('n', '<M-]>', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '<M-[>', '<C-o>', { desc = 'Previous location' })
vim.keymap.set('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
vim.keymap.set('n', '<M-x>', 'dd', { desc = 'Delete line' })
vim.keymap.set('x', '<M-x>', 'd', { desc = 'Delete selection' })

-- Some custom commands
vim.api.nvim_create_user_command('Buffer', function()
    local health = require 'utils.health'
    health.show_for_buffer()
end, { desc = 'Show buffer information', nargs = 0 })

-- misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')



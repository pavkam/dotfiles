local utils = require 'utils'
local notes = require 'utils.notes'
local toggles = require 'utils.toggles'

--- Re-maps a key
---@param mode string|table # the mode to map
---@param lhs string # the key to map
---@param rhs string|function # the mapping to use
---@param opts? { silent?: boolean, expr?: boolean, desc?: string, level?: integer } # optional modifiers
local map = function(mode, lhs, rhs, opts)
    opts = opts or {}
    if feature_level(opts.level or 0) then
        opts.level = nil
        vim.keymap.set(mode, lhs, rhs, opts)
    end
end

-- Disable some sequences
map({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
map('n', '<BS>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })
map('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
map('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })

-- Better normal mode navigation
map({ 'n', 'x' }, 'gg', function()
    if vim.v.count > 0 then
        vim.cmd('normal! ' .. vim.v.count .. 'gg')
    else
        vim.cmd 'normal! gg0'
    end
end, { desc = 'Start of buffer' })

map({ 'n', 'x' }, 'G', function()
    vim.cmd 'normal! G$'
end, { desc = 'End of buffer' })

-- move selection up/down
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection downward' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection upward' })

-- Better jump list navigation
map('n', ']]', '<C-i>', { desc = 'Next location' })
map('n', '[[', '<C-o>', { desc = 'Previous location' })

-- Add undo break-points
map('i', ',', ',<c-g>u')
map('i', '.', '.<c-g>u')
map('i', ';', ';<c-g>u')

-- Redo
map('n', 'U', '<C-r>', { desc = 'Redo' })

-- Some editor mappings
map('i', '<C-BS>', '<C-w>', { desc = 'Delete word' })

map('i', '<Tab>', function()
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

map('i', '<S-Tab>', '<C-d>', { desc = 'Unindent' })
map('n', '<Tab>', '>>', { desc = 'Indent' })
map('n', '<S-Tab>', '<<', { desc = 'Indent' })

-- Better page up/down
local function page_expr(dir)
    local jump = vim.api.nvim_win_get_height(0)
    if vim.v.count > 0 then
        jump = jump * vim.v.count
    end

    vim.cmd('normal! ' .. jump .. dir .. 'zz')
end
map({ 'i', 'n' }, '<PageUp>', function()
    page_expr 'k'
end, { desc = 'Page up' })
map({ 'i', 'n' }, '<PageDown>', function()
    page_expr 'j'
end, { desc = 'Page down' })

-- Disable the annoying yank on chnage
map({ 'n', 'x' }, 'c', [["_c]], { desc = 'Change' })
map({ 'n', 'x' }, 'C', [["_C]], { desc = 'Change' })
map('x', 'p', 'P', { desc = 'Paste' })
map('x', 'P', 'p', { desc = 'Yank & paste' })

-- window navigation
map('n', '<A-Tab>', '<C-W>w', { desc = 'Switch window' })
map('n', '<A-Left>', '<cmd>wincmd h<cr>', { desc = 'Go to left window' })
map('n', '<A-Right>', '<cmd>wincmd l<cr>', { desc = 'Go to right window' })
map('n', '<A-Down>', '<cmd>wincmd j<cr>', { desc = 'Go to window below' })
map('n', '<A-Up>', '<cmd>wincmd k<cr>', { desc = 'Go to window above' })
map('n', '\\', '<C-W>s', { desc = 'Split window below' })
map('n', '|', '<C-W>v', { desc = 'Split window right' })

-- terminal mappings
map('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Enter normal mode' })

-- buffer management
map('n', '<leader><leader>', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, 'e #')
end, { desc = 'Switch buffer', silent = true })
map('n', '<leader>bw', '<cmd>w<cr>', { desc = 'Save buffer' })

map('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
map('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- search
map({ 'i', 'n' }, '<esc>', '<cmd>nohlsearch<cr><esc>', { desc = 'Escape and clear highlight' })
map('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
map({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
map('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Previous search result' })
map({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Previous search result' })
map('x', '<C-r>', function()
    local selected_text = utils.get_selected_text()
    local command = ':<C-u>%s/\\<' .. selected_text .. '\\>//gI<Left><Left><Left>'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, false, true), 'n', false)
end, { desc = 'Replace selection' })
map('n', '<C-r>', [[:%s/\<<C-r><C-w>\>//gI<Left><Left><Left>]])

-- better indenting
map('x', '<', '<gv', { desc = 'Indent selection' })
map('x', '>', '>gv', { desc = 'Unindent selection' })

map('x', '<Tab>', '>gv', { desc = 'Indent selection' })
map('x', '<S-Tab>', '<gv', { desc = 'Unindent selection' })

-- tabs
map('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
map('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

-- Some useful keymaps for me
map('n', 'x', [["_x]], { desc = 'Delete character' })
map('n', '<Del>', [["_x]], { desc = 'Delete character' })
map('x', '<BS>', 'd', { desc = 'Delete selection' })

--- Inserts a new line and pastes
---@param op "o"|"O" # the operation to perform
local function ins_paste(op)
    local count = vim.v.count

    vim.cmd('normal! ' .. op)
    vim.cmd 'stopinsert'
    if count > 0 then
        vim.cmd('normal! ' .. count .. 'p')
    else
        vim.cmd 'normal! p'
    end
end

map('n', 'go', function()
    ins_paste 'o'
end, { desc = 'Paste below' })

map('n', 'gO', function()
    ins_paste 'O'
end, { desc = 'Paste below' })

-- Command mode remaps to make my life easier using the keyboard
map('c', '<Down>', function()
    if vim.fn.wildmenumode() then
        return '<C-n>'
    else
        return '<Down>'
    end
end, { expr = true })

map('c', '<Up>', function()
    if vim.fn.wildmenumode() then
        return '<C-p>'
    else
        return '<Up>'
    end
end, { expr = true })

map('c', '<Left>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Left>'
    else
        return '<Left>'
    end
end, { expr = true })

map('c', '<Right>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Right>'
    else
        return '<Right>'
    end
end, { expr = true })

-- quick-fix and locations list
map('n', '<leader>qm', function()
    vim.diagnostic.setqflist { open = true }
end, { desc = 'Diagnostics to quck-fix list' })
map('n', '<leader>qm', function()
    vim.diagnostic.setloclist { open = true }
end, { desc = 'Diagnostics to locations list' })
map('n', '<leader>qc', function()
    vim.fn.setqflist({}, 'r')
end, { desc = 'Clear quick-fix list' })
map('n', '<leader>qC', function()
    vim.fn.setloclist(0, {})
end, { desc = 'Clear locations list' })
map('n', '<leader>qq', '<cmd>copen<cr>', { desc = 'Show quick-fix list' })
map('n', '<leader>ql', '<cmd>lopen<cr>', { desc = 'Show locations list' })
map('n', ']q', '<cmd>cnext<cr>', { desc = 'Next quick-fix item' })
map('n', '[q', '<cmd>cprev<cr>', { desc = 'Previous quick-fix item' })
map('n', ']l', '<cmd>lnext<cr>', { desc = 'Next location item' })
map('n', '[l', '<cmd>lprev<cr>', { desc = 'Previous location item' })

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

-- diagnostics
local function jump_to_diagnostic(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    severity = severity and vim.diagnostic.severity[severity] or nil

    return function()
        go { severity = severity }
    end
end

map('n', ']m', jump_to_diagnostic(true), { desc = 'Next Diagnostic' })
map('n', '[m', jump_to_diagnostic(false), { desc = 'Previous Diagnostic' })
map('n', ']e', jump_to_diagnostic(true, 'ERROR'), { desc = 'Next Error' })
map('n', '[e', jump_to_diagnostic(false, 'ERROR'), { desc = 'Previous Error' })
map('n', ']w', jump_to_diagnostic(true, 'WARN'), { desc = 'Next Warning' })
map('n', '[w', jump_to_diagnostic(false, 'WARN'), { desc = 'Previous Warning' })

map('n', '<leader>uM', function()
    toggles.toggle_diagnostics()
end, { desc = 'Toggle global diagnostics' })

map('n', '<leader>um', function()
    toggles.toggle_diagnostics { buffer = vim.nvim.nvim_get_current_buf() }
end, { desc = 'Toggle buffer diagnostics' })

-- Treesitter
map('n', '<leader>ut', function()
    toggles.toggle_treesitter { buffer = vim.nvim.nvim_get_current_buf() }
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
        --TODO: use the shell extension
        set('n', '<leader>sJ', ':%!jq .<cr>', { desc = 'Pretty-format JSON' })
    end)
end

-- Notes
map('n', '<leader>nn', function()
    notes.find(true)
end, { desc = 'Browse global notes', level = 2 })

map('n', '<leader>nN', function()
    notes.find(false)
end, { desc = 'Browse project notes', level = 2 })

map('n', '<leader>ng', function()
    notes.grep(true)
end, { desc = 'Grep global notes', level = 2 })

map('n', '<leader>nG', function()
    notes.grep(false)
end, { desc = 'Grep project notes', level = 2 })

map('n', '<leader>nc', function()
    notes.edit(true)
end, { desc = 'Open global note', level = 2 })

map('n', '<leader>nC', function()
    notes.edit(false)
end, { desc = 'Open project note', level = 2 })

-- show hidden
map('n', '<leader>uh', function()
    toggles.toggle_ignore_hidden_files()
end, { desc = 'Toggle show hidden', level = 1 })

-- Specials using "Command/Super" key (when available!)
map('n', '<M-]>', '<C-i>', { desc = 'Next location' })
map('n', '<M-[>', '<C-o>', { desc = 'Previous location' })
map('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
map('n', '<M-x>', 'dd', { desc = 'Delete line' })
map('x', '<M-x>', 'd', { desc = 'Delete selection' })

-- misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

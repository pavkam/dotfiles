-- Editing keymaps extension: navigation, indentation, undo, yank, paste tweaks.
-- Replaces scattered editing keymaps from init2.lua.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local EditingKeymaps = Class('EditingKeymaps', Extension)

function EditingKeymaps:init()
    Extension.init(self, 'EditingKeymaps')
end

function EditingKeymaps:on_register(ctx)
    -- gg goes to line N or start of buffer with cursor at col 0
    ctx:keymap({ 'n', 'x' }, 'gg', function()
        if vim.v.count > 0 then
            Window.current():exec_normal(vim.v.count .. 'gg')
        else
            Window.current():exec_normal('gg0')
        end
    end, { desc = 'Start of buffer' })

    -- G goes to end of buffer with cursor at end of line
    ctx:keymap({ 'n', 'x' }, 'G', function()
        Window.current():exec_normal('G$')
    end, { desc = 'End of buffer' })

    -- Move selection up/down
    ctx:keymap('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
    ctx:keymap('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

    -- Better indenting (stays in visual mode)
    ctx:keymap('x', '<', '<gv', { desc = 'Dedent' })
    ctx:keymap('x', '>', '>gv', { desc = 'Indent' })
    ctx:keymap('x', '<Tab>', '>gv', { desc = 'Indent' })
    ctx:keymap('x', '<S-Tab>', '<gv', { desc = 'Dedent' })

    -- Undo breakpoints at punctuation in insert mode
    for _, key in ipairs({ '.', ',', '!', '?', ';', ':', '"', "'" }) do
        ctx:keymap('i', key, key .. '<c-g>u', { desc = 'Insert ' .. key .. ' + undo point' })
    end

    -- Redo with U
    ctx:keymap('n', 'U', '<C-r>', { desc = 'Redo' })

    -- Delete word backwards in insert mode
    ctx:keymap('i', '<C-BS>', '<C-w>', { desc = 'Delete word' })

    -- Smart Tab in insert mode: indent if cursor is in leading whitespace, else literal tab.
    -- Note: completion extension overrides insert-mode <Tab>/<S-Tab> when popup is visible.
    ctx:keymap('i', '<Tab>', function()
        local win = Window.current()
        local pos = win:cursor()
        local line = Buffer.current():line(pos.row)
        if line then
            local before = line:sub(1, pos.col)
            local after = line:sub(pos.col + 1)
            if before:match('^%s*$') and not after:match('^%s*$') then
                return '<C-t>'
            end
        end
        return '<Tab>'
    end, { desc = 'Indent/Tab', expr = true })

    ctx:keymap('i', '<S-Tab>', '<C-d>', { desc = 'Unindent' })

    ctx:keymap('n', '<Tab>', '>>', { desc = 'Indent' })
    ctx:keymap('n', '<S-Tab>', '<<', { desc = 'Dedent' })

    -- Page up/down centered
    local function page_move(dir)
        local jump = Window.current():height()
        if vim.v.count > 0 then jump = jump * vim.v.count end
        Window.current():exec_normal(jump .. dir .. 'zz')
    end

    ctx:keymap({ 'i', 'n' }, '<PageUp>', function() page_move('k') end, { desc = 'Page up' })
    ctx:keymap({ 'i', 'n' }, '<PageDown>', function() page_move('j') end, { desc = 'Page down' })
    ctx:keymap('x', '<S-PageUp>', function() page_move('k') end, { desc = 'Page up' })
    ctx:keymap('x', '<S-PageDown>', function() page_move('j') end, { desc = 'Page down' })

    -- Don't yank on change operations
    ctx:keymap({ 'n', 'x' }, 'c', '"_c', { desc = 'Change' })
    ctx:keymap({ 'n', 'x' }, 'C', '"_C', { desc = 'Change' })
    ctx:keymap('x', 'p', 'P', { desc = 'Paste' })
    ctx:keymap('x', 'P', 'p', { desc = 'Yank & paste' })
    ctx:keymap('n', 'x', '"_x', { desc = 'Delete char' })
    ctx:keymap('n', '<Del>', '"_x', { desc = 'Delete char' })
    ctx:keymap('x', '<BS>', 'd', { desc = 'Delete selection' })

    -- Don't yank empty lines
    ctx:keymap('n', 'dd', function()
        local pos = Window.current():cursor()
        if Buffer.current():line(pos.row):match('^%s*$') then
            return '"_dd'
        end
        return 'dd'
    end, { desc = 'Delete line', expr = true })

    -- Paste on new line
    ctx:keymap('n', 'gp', function()
        Window.current():exec_normal('o')
        IDE.ui:stop_insert()
        local count = vim.v.count > 0 and vim.v.count or 1
        Window.current():exec_normal(count .. 'p')
    end, { desc = 'Paste below' })

    ctx:keymap('n', 'gP', function()
        Window.current():exec_normal('O')
        IDE.ui:stop_insert()
        local count = vim.v.count > 0 and vim.v.count or 1
        Window.current():exec_normal(count .. 'p')
    end, { desc = 'Paste above' })

    -- Alt shortcuts
    ctx:keymap('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
    ctx:keymap('n', '<M-x>', 'dd', { desc = 'Delete line' })
    ctx:keymap('x', '<M-x>', 'd', { desc = 'Delete selection' })
    ctx:keymap('n', '<M-a>', 'ggVG', { desc = 'Select all' })

    -- Repeat in visual mode
    ctx:keymap('x', '.', ':norm .<CR>', { desc = 'Repeat edit' })
    ctx:keymap('x', '@', ':norm @q<CR>', { desc = 'Repeat macro' })

    -- Mouse in insert mode: keep insert mode, just reposition cursor (GUI editor behavior)
    -- Default neovim behavior already handles this correctly — no override needed

    -- Smart increment/decrement (treesitter-aware)
    ctx:keymap('n', '<C-a>', function()
        local buf = Buffer.current()
        if not buf:is_normal() or not buf:ast():increment_at_cursor(1) then
            Window.current():exec_normal('\x01')  -- <C-a>
        end
    end, { desc = 'Increment/Toggle value' })

    ctx:keymap('n', '<C-x>', function()
        local buf = Buffer.current()
        if not buf:is_normal() or not buf:ast():increment_at_cursor(-1) then
            Window.current():exec_normal('\x18')  -- <C-x>
        end
    end, { desc = 'Decrement/Toggle value' })

    -- Format buffer (Ctrl+Shift+I, not = which is the indent operator)

    -- Disable Space and BS in normal mode
    ctx:keymap({ 'n', 'v' }, '<Space>', '<Nop>', { desc = 'Leader prefix' })
    ctx:keymap('n', '<BS>', '<Nop>', { desc = 'Disabled' })

    -- Window splits (Shift+Alt to avoid menu hotkey conflicts)
    ctx:keymap('n', '<M-S-v>', function() IDE.actions:execute('window.splitV') end, { desc = 'Split vertical' })
    ctx:keymap('n', '<M-S-h>', function() IDE.actions:execute('window.splitH') end, { desc = 'Split horizontal' })

    -- Jump list navigation
    -- ]] and [[ left for treesitter textobjects (function/class navigation)
    ctx:keymap('n', '<M-]>', '<C-i>', { desc = 'Next location' })
    ctx:keymap('n', '<M-[>', '<C-o>', { desc = 'Previous location' })

    -- Word-wrap aware j/k navigation
    ctx:keymap({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move down' })
    ctx:keymap({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move up' })
    ctx:keymap({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", { expr = true, desc = 'Move down' })
    ctx:keymap({ 'n', 'x' }, '<Up>', "v:count == 0 ? 'gk' : 'k'", { expr = true, desc = 'Move up' })

    -- F12 toggles insert/normal mode
    ctx:keymap('n', '<F12>', 'i', { desc = 'Insert mode' })
    ctx:keymap('i', '<F12>', '<Esc>', { desc = 'Normal mode' })

    -- Insert-mode mouse: exit insert mode on click
    ctx:keymap('i', '<LeftMouse>', '<Esc><LeftMouse>', { desc = 'Click exits insert' })
    ctx:keymap('i', '<RightMouse>', '<Esc><RightMouse>', { desc = 'Right-click exits insert' })

    -- Format buffer/selection with =
    ctx:keymap({ 'n', 'x' }, '=', function()
        local buf = Buffer.current()
        if buf:is_normal() then buf:format() end
    end, { desc = 'Format' })

    -- Terminal
    ctx:keymap('t', '<esc><esc>', '<c-\\><c-n>', { desc = 'Exit terminal' })
end

return EditingKeymaps

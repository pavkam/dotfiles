-- Buffer keymaps extension: buffer management and diagnostic navigation.
-- Replaces scattered keymaps from init2.lua with a proper extension.

local Extension = require 'ide.Extension'

local BufferKeymaps = Class('BufferKeymaps', Extension)

function BufferKeymaps:init()
    Extension.init(self, 'BufferKeymaps')
end

function BufferKeymaps:on_register(ctx)
    -- Switch to alternate buffer
    ctx:keymap('n', '<leader><leader>', function()
        local buf = IDE.buffers:current()
        if not buf:is_normal() then return end
        local alt = IDE.buffers:alternate()
        if alt then IDE.buffers:switch_to(alt) end
    end, { desc = 'Switch buffer' })

    -- Close current buffer
    ctx:keymap('n', '<leader>c', function()
        IDE.buffers:current():close()
    end, { desc = 'Close buffer' })

    -- Close other buffers
    ctx:keymap('n', '<leader>C', function()
        local current = IDE.buffers:current():id()
        for buf in IDE.buffers:iter() do
            if buf:id() ~= current then buf:close(true) end
        end
    end, { desc = 'Close other buffers' })

    -- Alt-N switches to buffer N
    for i = 1, 9 do
        ctx:keymap('n', '<M-' .. i .. '>', function()
            local bufs = IDE.buffers:listed()
            if bufs[i] then IDE.buffers:switch_to(bufs[i]) end
        end, { desc = 'Go to buffer ' .. i })
    end

    -- Save
    ctx:keymap('n', '<leader>w', '<cmd>w<cr>', { desc = 'Save buffer' })
    ctx:keymap('n', '<leader>W', '<cmd>wa<cr>', { desc = 'Save all buffers' })

    -- Buffer navigation
    ctx:keymap('n', '[b', '<cmd>bprevious<cr>', { desc = 'Previous buffer' })
    ctx:keymap('n', ']b', '<cmd>bnext<cr>', { desc = 'Next buffer' })

    -- Tab navigation
    ctx:keymap('n', ']t', '<cmd>tabnext<cr>', { desc = 'Next tab' })
    ctx:keymap('n', '[t', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })

    -- Diagnostic navigation
    local DS = require 'ide.DiagnosticSet'
    ctx:keymap('n', ']m', function() IDE.buffers:current():diagnostics():next() end, { desc = 'Next Diagnostic' })
    ctx:keymap('n', '[m', function() IDE.buffers:current():diagnostics():prev() end, { desc = 'Previous Diagnostic' })
    ctx:keymap('n', ']e', function() IDE.buffers:current():diagnostics():next(DS.ERROR) end, { desc = 'Next Error' })
    ctx:keymap('n', '[e', function() IDE.buffers:current():diagnostics():prev(DS.ERROR) end, { desc = 'Previous Error' })
    ctx:keymap('n', ']w', function() IDE.buffers:current():diagnostics():next(DS.WARN) end, { desc = 'Next Warning' })
    ctx:keymap('n', '[w', function() IDE.buffers:current():diagnostics():prev(DS.WARN) end, { desc = 'Previous Warning' })

    -- Options toggle
    ctx:keymap('n', '<leader>u', function()
        IDE.config:manage()
    end, { desc = 'Manage options' })

    -- File navigation shortcuts
    ctx:keymap('n', '<C-e>', function() IDE.actions:execute('file.explorer') end, { desc = 'File Explorer' })
    ctx:keymap('n', '<leader>e', function() IDE.actions:execute('file.explorer') end, { desc = 'File Explorer' })
    ctx:keymap('n', '<C-p>', function() IDE.actions:execute('file.open') end, { desc = 'Open file' })
    ctx:keymap('n', '<C-b>', function() IDE.actions:execute('view.buffers') end, { desc = 'Buffer picker' })

    -- Standard IDE shortcuts
    ctx:keymap({ 'n', 'i' }, '<C-s>', function()
        vim.cmd('stopinsert')
        IDE.actions:execute('file.save')
    end, { desc = 'Save file' })

    ctx:keymap({ 'n', 'i' }, '<C-S-s>', function()
        vim.cmd('stopinsert')
        IDE.actions:execute('file.saveAs')
    end, { desc = 'Save As' })

    ctx:keymap('n', '<C-f>', function()
        IDE.actions:execute('file.grep')
    end, { desc = 'Find in files' })

    ctx:keymap('n', '<C-z>', function()
        local buf = IDE.buffers:current()
        if buf:is_normal() then buf:undo() end
    end, { desc = 'Undo' })

    ctx:keymap('n', '<C-y>', function()
        local buf = IDE.buffers:current()
        if buf:is_normal() then buf:redo() end
    end, { desc = 'Redo' })

    ctx:keymap('n', '<C-w>', function()
        IDE.actions:execute('editor.close')
    end, { desc = 'Close buffer' })

    -- Navigation history (like VS Code Alt+Left/Right)
    ctx:keymap('n', '<M-Left>', '<C-o>', { desc = 'Go back' })
    ctx:keymap('n', '<M-Right>', '<C-i>', { desc = 'Go forward' })

    ctx:keymap('n', '<C-g>', function()
        local buf = IDE.buffers:current()
        if not buf or not buf:is_normal() then return end
        local total = buf:line_count()
        local current = require('ide.Window').current():cursor().row

        IDE.ui:input('Go to line (1-' .. total .. '): ', function(input)
            if not input or input == '' then return end
            local line = tonumber(input)
            if line and line >= 1 and line <= total then
                require('ide.Window').current():set_cursor(require('ide.Position')(line, 1))
                vim.cmd('normal! zz')
            end
        end, { default = tostring(current) })
    end, { desc = 'Go to line' })
end

return BufferKeymaps

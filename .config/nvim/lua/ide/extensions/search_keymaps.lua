-- Search keymaps extension: search, replace, hlsearch, grep, pickers, command mode, q-close.
-- Final extraction from init2.lua + telescope.lua.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local SearchKeymaps = Class('SearchKeymaps', Extension)

function SearchKeymaps:init()
    Extension.init(self, 'SearchKeymaps')
end

function SearchKeymaps:on_register(ctx)
    -- Escape clears search highlight only when no dialogs/pickers are open
    ctx:keymap('n', '<esc>', function()
        local dominated = false
        for _, w in ipairs(Window.list()) do
            if w:is_floating() then
                local cfg = w:config()
                if cfg.zindex and cfg.zindex >= 100 then
                    dominated = true
                    break
                end
            end
        end
        if not dominated then
            IDE.ui:clear_search_highlight()
        end
        return '<esc>'
    end, { expr = true, desc = 'Escape / clear highlight' })

    -- Consistent n/N direction regardless of / vs ?
    ctx:keymap('n', 'n', "'Nn'[v:searchforward].'zv'", { expr = true, desc = 'Next search result' })
    ctx:keymap({ 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next search result' })
    ctx:keymap('n', 'N', "'nN'[v:searchforward].'zv'", { expr = true, desc = 'Prev search result' })
    ctx:keymap({ 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Prev search result' })

    -- \ handled by treesitter_textobjects (smart word/scope selection)

    -- Replace selection with C-r
    local function get_visual_text()
        local old = IDE.ui:get_register('a')
        Window.current():exec_normal('"aygv')
        local text = IDE.ui:get_register('a'):gsub('/', '\\/'):gsub('\n', '\\n')
        IDE.ui:set_register('a', old)
        return text
    end

    ctx:keymap('x', '<C-r>', function()
        local text = get_visual_text()
        IDE.keys:feed(IDE.text:rename_expression({ orig = text }))
    end, { desc = 'Replace selection' })

    ctx:keymap('x', '<C-S-r>', function()
        local text = get_visual_text()
        IDE.keys:feed(IDE.text:rename_expression({ orig = text, whole_word = true }))
    end, { desc = 'Replace selection (whole word)' })

    ctx:keymap('n', '<C-r>', IDE.text:rename_expression(), { desc = 'Replace word under cursor' })
    ctx:keymap('n', '<C-S-r>', IDE.text:rename_expression({ whole_word = true }), { desc = 'Replace word (whole word)' })

    -- Auto hlsearch: highlight only when actively searching
    vim.on_key(function(char)
        if IDE.ui:mode().mode == 'n' then
            local new_hl = vim.tbl_contains({ '<CR>', 'n', 'N', '*', '#', '?', '/' }, IDE.ui:key_name(char))
            if IDE.config:option('hlsearch') ~= new_hl then
                IDE.config:set_option('hlsearch', new_hl)
            end
        end
    end, Buffer.create_namespace('auto_hlsearch'))

    -- File finder
    ctx:keymap('n', '<leader>f', function()
        IDE.ui.finder:files()
    end, { desc = 'Find files' })

    -- Grep in all files (pre-fill visual selection)
    ctx:keymap({ 'n', 'v' }, '<M-f>', function()
        local sel = Window.current():selected_text()
        local search = (sel ~= '') and sel or nil
        IDE.ui.finder:grep({ search = search })
    end, { desc = 'Grep in files' })

    -- Grep with smart selection (find and replace)
    ctx:keymap({ 'n', 'v' }, '<M-S-f>', function()
        local sel = Window.current():selected_text()
        local search = (sel ~= '') and sel or nil
        IDE.ui.finder:grep({ search = search })
    end, { desc = 'Grep in files (selection)' })

    -- Spell suggestions picker
    ctx:keymap('n', 'z=', function()
        local word = vim.fn.expand('<cword>')
        local suggestions = vim.fn.spellsuggest(word, 20)
        if #suggestions == 0 then
            IDE.ui:info('No suggestions for: ' .. word)
            return
        end
        IDE.ui:select(suggestions, { prompt = 'Spell: ' .. word }, function(choice)
            if choice then
                Window.current():exec_normal('ciw' .. choice)
            end
        end)
    end, { desc = 'Spell suggestions' })

    -- Marks picker
    ctx:keymap('n', "''", function()
        local marks_raw = vim.fn.getmarklist(Buffer.current():id())
        local global_marks = vim.fn.getmarklist()
        local items = {}
        for _, m in ipairs(marks_raw) do
            local mark = m.mark:sub(2)
            local line = m.pos[2]
            local text = Buffer.current():line(line) or ''
            items[#items + 1] = {
                text = string.format("'%s  line %d: %s", mark, line, vim.trim(text)),
                value = mark,
            }
        end
        for _, m in ipairs(global_marks) do
            local mark = m.mark:sub(2)
            if mark:match('^%u$') then
                local file = m.file or ''
                local line = m.pos[2]
                items[#items + 1] = {
                    text = string.format("'%s  %s:%d", mark, vim.fn.fnamemodify(file, ':~:.'), line),
                    value = mark,
                }
            end
        end
        if #items == 0 then
            IDE.ui:info('No marks set')
            return
        end
        IDE.ui:select(items, {
            prompt = 'Marks',
            format_item = function(item) return item.text end,
        }, function(choice)
            if choice then
                Window.current():exec_normal("'" .. choice.value)
            end
        end)
    end, { desc = 'Marks' })

    -- Registers picker
    ctx:keymap('n', '""', function()
        local reg_names = vim.split('0123456789abcdefghijklmnopqrstuvwxyz"+-*/', '', { plain = true })
        local items = {}
        for _, r in ipairs(reg_names) do
            local content = vim.fn.getreg(r, 1)
            if content and content ~= '' then
                local preview = content:gsub('\n', '\\n')
                if #preview > 60 then preview = preview:sub(1, 60) .. '...' end
                items[#items + 1] = {
                    text = string.format('"%s  %s', r, preview),
                    value = r,
                }
            end
        end
        if #items == 0 then
            IDE.ui:info('No registers with content')
            return
        end
        IDE.ui:select(items, {
            prompt = 'Registers',
            format_item = function(item) return item.text end,
        }, function(choice)
            if choice then
                Window.current():exec_normal('"' .. choice.value .. 'p')
            end
        end)
    end, { desc = 'Registers' })

    -- Key groups for hint popup (prefix labels)
    if IDE.keys and IDE.keys.group then
        IDE.keys:group('g', { desc = 'Go-to', mode = { 'n', 'v' } })
        IDE.keys:group(']', { desc = 'Next', mode = { 'n', 'v' } })
        IDE.keys:group('[', { desc = 'Previous', mode = { 'n', 'v' } })
        IDE.keys:group('z', { desc = 'Fold/Spell', mode = { 'n', 'v' } })
        IDE.keys:group('<leader>x', { desc = 'AI', mode = 'n' })
    end

    -- Command mode: arrow keys navigate wildmenu
    ctx:keymap('c', '<Down>', function()
        return IDE.ui:is_wildmenu_active() and '<C-n>' or '<Down>'
    end, { expr = true, desc = 'Wildmenu down' })

    ctx:keymap('c', '<Up>', function()
        return IDE.ui:is_wildmenu_active() and '<C-p>' or '<Up>'
    end, { expr = true, desc = 'Wildmenu up' })

    ctx:keymap('c', '<Left>', function()
        return IDE.ui:is_wildmenu_active() and '<Space><BS><Left>' or '<Left>'
    end, { expr = true, desc = 'Wildmenu left' })

    ctx:keymap('c', '<Right>', function()
        return IDE.ui:is_wildmenu_active() and '<Space><BS><Right>' or '<Right>'
    end, { expr = true, desc = 'Wildmenu right' })

    -- q/Esc closes special windows (help, qf, etc.)
    ctx:hook('FileType', function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        ctx:keymap('n', 'q', '<cmd>close<cr>', { buffer = evt.buf })
        ctx:keymap('n', '<Esc>', '<cmd>close<cr>', { buffer = evt.buf })
    end, { pattern = Buffer.SPECIAL_FILETYPES, desc = 'q closes special windows' })

    ctx:hook('FileType', function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        ctx:keymap('n', 'q', '<cmd>close<cr>', { buffer = evt.buf })
        ctx:keymap('n', '<Esc>', '<cmd>close<cr>', { buffer = evt.buf })
    end, { pattern = 'help', desc = 'q closes help' })
end

return SearchKeymaps

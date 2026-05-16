-- Spelling extension: spell checking, custom dictionaries, word marking.
-- Replaces legacy spelling.lua.

local Extension = require 'ide.Extension'
local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Spelling = Class('Spelling', Extension)

function Spelling:init()
    Extension.init(self, 'Spelling')
end

function Spelling:_swap_dictionary()
    local project = IDE:project()
    local win = Window.current()
    local buf = Buffer.current()
    local current_file = buf:option('spellfile')
    if type(current_file) == 'string' then
        current_file = current_file ~= '' and current_file or nil
    end

    if not project then
        if current_file then
            IDE.ui:info('Disabling custom spelling dictionary')
        end
        buf:set_option('spellfile', '')
        return
    end

    local base_lang = buf:option('spelllang')
    if type(base_lang) == 'string' then base_lang = vim.split(base_lang, ',')[1] or 'en' end
    local spl_file = IDE.fs:join(project:root(), '.nvim', base_lang .. '.add')

    if current_file ~= spl_file then
        buf:set_option('spellfile', spl_file)
    end
end

function Spelling:_toggle_typos_lsp(enabled)
    for _, client in ipairs(IDE.lsp:clients_by_name('typos_lsp')) do
        if enabled then client:start() else client:stop() end
    end
end

function Spelling:_mark_word(good, global)
    local word = IDE.ui:word_under_cursor()
    local buf = Buffer.current()
    if global then
        local current = buf:option('spellfile')
        buf:set_option('spellfile', '')
        buf:spell_word(word, good)
        buf:set_option('spellfile', current)
    else
        local spf = buf:option('spellfile')
        if type(spf) == 'string' and spf ~= '' then
            IDE.fs:mkdir(IDE.fs:dirname(spf))
        end
        buf:spell_word(word, good)
    end
end

function Spelling:on_register(ctx)
    local ext = self

    -- Spelling toggle
    ctx:toggle('spelling', {
        desc = 'Spell checking',
        default = IDE.config:option('spell'),
        on_toggle = function(enabled)
            IDE.config:set_option('spell', enabled)
            ext:_toggle_typos_lsp(enabled)
        end,
    })

    -- Disable spell in special buffers
    ctx:hook('BufWinEnter', function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        if not buf:is_normal() and buf:filetype() ~= '' and buf:filetype() ~= 'ide-filetree' then
            Window.current():set_option('spell', false)
        end
    end, { desc = 'Disable spell in special buffers' })

    -- Enable/disable spell per filetype
    ctx:hook('FileType', function(evt)
        if not Buffer.is_valid(evt.buf) then return end
        local buf = Buffer.get(evt.buf)
        local wins = Window.for_buffer(evt.buf)
        local function set_spell(val)
            for _, win in ipairs(wins) do
                pcall(function() win:set_option('spell', val) end)
            end
        end
        if not buf:is_normal() then
            set_spell(false)
        elseif Buffer.is_transient(evt.buf) or buf:filetype() == 'markdown' then
            set_spell(true)
        end
    end, { desc = 'Spell per filetype' })

    -- Swap dictionary on events
    ctx:hook({ 'UIEnter', 'LspAttach', 'LspDetach' }, function()
        ctx:schedule(function() ext:_swap_dictionary() end)
    end, { desc = 'Swap spelling dictionary' })

    ctx:hook({ 'FocusGained', 'TermClose', 'TermLeave', 'DirChanged' }, function()
        ctx:schedule(function() ext:_swap_dictionary() end)
    end, { desc = 'Swap dictionary on focus' })

    -- Word marking keymaps
    ctx:keymap('n', 'zg', function() ext:_mark_word(true, false) end, { desc = 'Add word to local dict' })
    ctx:keymap('n', 'zG', function() ext:_mark_word(true, true) end, { desc = 'Add word to global dict' })
    ctx:keymap('n', 'zw', function() ext:_mark_word(false, false) end, { desc = 'Mark word bad (local)' })
    ctx:keymap('n', 'zW', function() ext:_mark_word(false, true) end, { desc = 'Mark word bad (global)' })
end

return Spelling

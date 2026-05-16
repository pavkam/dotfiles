-- Editor defaults extension: filetype additions, abbreviations, basic keymaps.
-- Replaces scattered wiring from init2.lua with a proper extension.

local Extension = require 'ide.Extension'
local Window = require 'ide.Window'

local EditorDefaults = Class('EditorDefaults', Extension)

function EditorDefaults:init()
    Extension.init(self, 'EditorDefaults')
end

function EditorDefaults:on_register(ctx)
    -- Additional filetype detection
    vim.filetype.add {
        extension = { snap = 'javascript' },
        pattern = { ['.env'] = 'bash', ['.env.*'] = 'bash' },
    }

    -- Window options per filetype
    ctx:hook('FileType', function()
        Window.current():set_option('winfixbuf', true)
    end, { pattern = { 'help', 'query', 'qf' }, desc = 'Lock special buffers' })

    ctx:hook('FileType', function()
        Window.current():set_option('wrap', true)
    end, { pattern = { 'markdown', 'gitcommit', 'gitrebase', 'hgcommit' }, desc = 'Wrap text filetypes' })

    -- Command abbreviations (typo corrections)
    for _, pair in ipairs({ {'qw','wq'}, {'Wq','wq'}, {'WQ','wq'}, {'Qa','qa'}, {'Bd','bd'}, {'bD','bd'} }) do
        IDE.ui:abbreviate(pair[1], pair[2])
    end

    -- Disable default right-click popup (replaced by IDE.mouse)
    IDE.ui:clear_popup_menu()

    -- F12 toggles between insert and normal mode
    ctx:keymap('n', '<F12>', 'i', { desc = 'Insert mode' })
    ctx:keymap('i', '<F12>', '<Esc>', { desc = 'Normal mode' })

    -- j/k and arrows respect word wrap
    ctx:keymap('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
    ctx:keymap('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })
    ctx:keymap('n', '<Up>', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move cursor up', expr = true })
    ctx:keymap('n', '<Down>', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move cursor down', expr = true })

    ctx:notify('Editor defaults active')
end

return EditorDefaults

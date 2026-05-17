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

    -- F12, j/k, Up/Down are registered by EditingKeymaps (with visual mode support)
    ctx:notify('Editor defaults active')
end

return EditorDefaults

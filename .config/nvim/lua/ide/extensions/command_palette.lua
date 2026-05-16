-- Command Palette Extension: Ctrl+Shift+P to browse and execute all IDE actions.
-- Lists all registered actions from the ActionRegistry with fuzzy search.

local Extension = require 'ide.Extension'

local CommandPalette = Class('CommandPalette', Extension)

function CommandPalette:init()
    Extension.init(self, 'CommandPalette')
end

function CommandPalette:on_register(ctx)
    ctx:action('app.commandPalette', 'Command palette', function()
        self:_open()
    end)

    ctx:keymap('n', '<C-S-p>', 'app.commandPalette')
    ctx:keymap('n', '<leader>:', 'app.commandPalette', { desc = 'Command palette' })

    ctx:command('IDEActions', function()
        self:_open()
    end, { desc = 'Open command palette' })
end

function CommandPalette:_open()
    local Picker = require 'ide.toolkit.Picker'
    local actions = IDE.actions:list()

    if #actions == 0 then
        IDE.ui:warn('No actions registered')
        return
    end

    Picker({
        title = '  Command Palette',
        items = actions,
        width = 0.5,
        height = math.min(#actions + 2, 25),
        auto_search = true,
        format = function(item)
            return item.desc
        end,
        on_select = function(item)
            IDE.actions:execute(item.name)
        end,
    }):show()
end

---@return string
function CommandPalette:__tostring()
    return 'CommandPalette'
end

return CommandPalette

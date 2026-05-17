-- Command Palette Extension: Ctrl+Shift+P to browse and execute all IDE actions.
-- Lists all registered actions from the ActionRegistry with fuzzy search.
-- Shows keybinding shortcuts right-aligned for each action.

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

--- Format a key sequence for display.
---@param lhs string
---@return string
local function format_key(lhs)
    return lhs
        :gsub('<leader>', 'SPC ')
        :gsub('<C%-', 'Ctrl+'):gsub('<S%-', 'Shift+')
        :gsub('<M%-', 'Alt+'):gsub('<CR>', 'Enter')
        :gsub('<F(%d+)>', 'F%1')
        :gsub('>', '')
end

--- Build a reverse lookup: action_name → keybinding display string.
--- Uses two sources: (1) extension keymap metadata, (2) vim keymap desc matching.
---@return table<string, string>
local function build_shortcut_map()
    local map = {}
    if not IDE then return map end

    -- Source 1: extension keymaps with explicit action names
    for _, ext in ipairs(IDE:extensions()) do
        for _, km in ipairs(ext._keymaps or {}) do
            if km.action and not km.buffer then
                local modes = type(km.mode) == 'table' and km.mode or { km.mode }
                for _, mode in ipairs(modes) do
                    if mode == 'n' and not map[km.action] then
                        map[km.action] = format_key(km.lhs)
                    end
                end
            end
        end
    end

    -- Source 2: vim normal-mode keymaps whose desc matches an action desc
    local desc_to_action = {}
    for _, a in ipairs(IDE.actions:list()) do
        if a.desc then desc_to_action[a.desc] = a.name end
    end
    for _, km in ipairs(vim.api.nvim_get_keymap('n')) do
        if km.desc and desc_to_action[km.desc] and not map[desc_to_action[km.desc]] then
            map[desc_to_action[km.desc]] = format_key(km.lhs)
        end
    end

    return map
end

--- Category icons for action groups.
local _category_icons = {
    file = '', editor = '', lsp = '󰒋', debug = '',
    view = '', git = '', terminal = '', test = '',
    app = '󰀻',
}

function CommandPalette:_open()
    local SelectPicker = require 'ide.toolkit.SelectPicker'
    local actions = IDE.actions:list()

    if #actions == 0 then
        IDE.ui:warn('No actions registered')
        return
    end

    local shortcuts = build_shortcut_map()

    local items = {}
    for _, a in ipairs(actions) do
        local cat = a.category or (a.name:match('^([^.]+)%.') or '')
        local icon = _category_icons[cat] or '󰀻'
        items[#items + 1] = {
            text = a.desc or a.name,
            icon = icon,
            hint = shortcuts[a.name] or '',
            _action_name = a.name,
        }
    end

    SelectPicker({
        title = '  Command Palette',
        items = items,
        width = 0.5,
        height = math.min(#items + 3, 25),
        on_select = function(item)
            IDE.actions:execute(item._action_name)
        end,
    }):show()
end

---@return string
function CommandPalette:__tostring()
    return 'CommandPalette'
end

return CommandPalette

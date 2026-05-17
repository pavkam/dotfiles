-- Command Palette Extension: Ctrl+Shift+P to browse and execute all IDE actions.
-- Lists all registered actions from the ActionRegistry with fuzzy search.
-- Shows keybinding shortcuts right-aligned for each action.
-- Recently used actions appear at the top.

local Extension = require 'ide.Extension'

local CommandPalette = Class('CommandPalette', Extension)

function CommandPalette:init()
    Extension.init(self, 'CommandPalette')
    self._recent = {} -- ordered list of recently executed action names
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

--- Track an action as recently used.
---@param name string
function CommandPalette:_track_recent(name)
    -- Remove existing entry if present
    for i, n in ipairs(self._recent) do
        if n == name then table.remove(self._recent, i); break end
    end
    -- Insert at front
    table.insert(self._recent, 1, name)
    -- Cap at 10
    if #self._recent > 10 then self._recent[#self._recent] = nil end
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

    -- Build items with MRU sorting: recent actions first, then alphabetical
    local recent_set = {}
    for i, name in ipairs(self._recent) do
        recent_set[name] = i
    end

    -- Context detection for action filtering
    local buf = IDE.buffers:current()
    local has_lsp = buf and buf:is_valid() and buf:is_normal() and #buf:lsp_clients() > 0
    local has_file = buf and buf:is_valid() and buf:is_normal()

    local items = {}
    for _, a in ipairs(actions) do
        local cat = a.category or (a.name:match('^([^.]+)%.') or '')
        local icon = _category_icons[cat] or '󰀻'
        -- Context-aware hint: show availability
        local hint = shortcuts[a.name] or ''
        local available = true
        if cat == 'lsp' and not has_lsp then
            available = false
        elseif cat == 'debug' and not IDE.debug:is_active() then
            if a.name ~= 'debug.continue' and a.name ~= 'debug.toggleBreakpoint' then
                available = false
            end
        elseif (cat == 'editor' or cat == 'file') and not has_file then
            if a.name ~= 'file.open' and a.name ~= 'file.new' and a.name ~= 'file.recent'
                and a.name ~= 'file.explorer' and a.name ~= 'app.commandPalette' then
                available = false
            end
        end

        if available then
            items[#items + 1] = {
                text = a.desc or a.name,
                icon = icon,
                hint = hint,
                _action_name = a.name,
                _recent_rank = recent_set[a.name] or 999,
            }
        end
    end

    -- Sort: recently used first, then alphabetical
    table.sort(items, function(a, b)
        if a._recent_rank ~= b._recent_rank then
            return a._recent_rank < b._recent_rank
        end
        return a.text < b.text
    end)

    local cp = self
    SelectPicker({
        title = '  Command Palette',
        items = items,
        width = 0.5,
        height = math.min(#items + 3, 25),
        on_select = function(item)
            cp:_track_recent(item._action_name)
            IDE.actions:execute(item._action_name)
        end,
    }):show()
end

---@return string
function CommandPalette:__tostring()
    return 'CommandPalette'
end

return CommandPalette

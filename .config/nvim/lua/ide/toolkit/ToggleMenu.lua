-- ToggleMenu: a floating panel showing all IDE toggles with on/off status.
-- Uses a reactive function component for rendering with useState for selection.

local Panel = require 'ide.toolkit.Panel'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local ToggleMenu = Class('ToggleMenu', Panel)

---@param opts { toggles: { name: string, desc: string, value: boolean, scope: string }[], on_toggle: fun(name: string) }
function ToggleMenu:init(opts)
    Panel.init(self, {
        title = '  Options',
        width = 0.4,
        height = math.min(#opts.toggles + 2, 20),
        enter = true,
    })
    self._toggles = opts.toggles
    self._on_toggle = opts.on_toggle
end

--- Function component for toggle menu content.
local function ToggleMenuView(props)
    local toggles = props.toggles or {}
    local selected, setSelected = hooks.useState(1)

    -- Store state accessors for external keybinds
    props._state = {
        selected = selected, setSelected = setSelected,
        toggles = toggles,
    }

    local children = {}
    for i, t in ipairs(toggles) do
        local icon = t.value and ' 󰄬 ' or ' 󰅖 '
        local icon_hl = t.value and 'DiagnosticOk' or 'DiagnosticError'
        local is_sel = i == selected

        if is_sel then
            children[#children + 1] = {
                type = 'row', hl = 'IDEPanelSelected',
                children = {
                    { type = 'text', text = icon, hl = icon_hl },
                    { type = 'text', text = t.desc, hl = 'IDEPanelSelected' },
                },
            }
        else
            children[#children + 1] = {
                type = 'row',
                children = {
                    { type = 'text', text = icon, hl = icon_hl },
                    { type = 'text', text = t.desc, hl = t.value and 'Normal' or 'Comment' },
                },
            }
        end
    end

    -- Status bar
    children[#children + 1] = {
        type = 'status',
        text = string.format('%d/%d ', math.min(selected, #toggles), #toggles),
        hl = 'IDEPanelDim',
        text_hl = 'IDEPanelCounter',
    }

    return children
end

function ToggleMenu:_on_mount()
    local menu = self
    self._component = C.mount(ToggleMenuView, {
        toggles = self._toggles,
        _state = {},
    }, self:buffer(), self._win)

    local function state()
        return self._component and self._component.ctx.props._state or {}
    end

    local function toggle_selected()
        local s = state()
        local t = s.toggles and s.toggles[s.selected]
        if t and menu._on_toggle then
            menu._on_toggle(t.name)
            t.value = not t.value
            -- Force re-render with updated toggles
            if self._component then
                C.update(self._component, { toggles = self._toggles, _state = {} })
            end
        end
    end

    self:map('n', 'j', function()
        local s = state()
        if s.setSelected and s.toggles then
            s.setSelected(math.min((s.selected or 1) + 1, #s.toggles))
        end
    end)

    self:map('n', 'k', function()
        local s = state()
        if s.setSelected then
            s.setSelected(math.max((s.selected or 1) - 1, 1))
        end
    end)

    self:map('n', '<CR>', toggle_selected)
    self:map('n', '<Space>', toggle_selected)
end

function ToggleMenu:hide()
    if self._component then
        C.unmount(self._component)
        self._component = nil
    end
    Panel.hide(self)
end

---@return string
function ToggleMenu:__tostring()
    return string.format('ToggleMenu(%d options)', #self._toggles)
end

return ToggleMenu

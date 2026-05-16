-- ToggleMenuView: reactive version of the ToggleMenu component.
-- Demonstrates the reactive framework with real IDE functionality.
-- State: { toggles, selected }. Renders via VNode tree.

local Component = require 'ide.toolkit.reactive.Component'
local VNode = require 'ide.toolkit.reactive.VNode'

local ToggleMenuView = Class('ToggleMenuView', Component)

function ToggleMenuView:init(props)
    Component.init(self, props)
    self.state = {
        toggles = props.toggles or {},
        selected = 1,
    }
end

function ToggleMenuView:render()
    local V = VNode
    local rows = {}

    for i, t in ipairs(self.state.toggles) do
        local icon = t.value and '󰄬 ' or '󰅖 '
        local icon_hl = t.value and 'DiagnosticOk' or 'DiagnosticError'
        local text_hl = t.value and 'Normal' or 'Comment'
        local sel = i == self.state.selected and '▸' or ' '

        rows[#rows + 1] = V.HBox({ key = t.name }, {
            V.Label(sel, 'IDEMenuItemSelected'),
            V.Label(icon, icon_hl),
            V.Label(t.desc, text_hl),
            V.Spacer(),
            V.Label(t.scope .. ' ', t.scope == 'global' and 'Special' or 'String'),
        })
    end

    return V.VBox({}, rows)
end

--- Move selection cursor.
---@param dir integer # 1 or -1
function ToggleMenuView:move(dir)
    local count = #self.state.toggles
    if count == 0 then return end
    local new_sel = self.state.selected + dir
    if new_sel < 1 then new_sel = count end
    if new_sel > count then new_sel = 1 end
    self:setState({ selected = new_sel })
end

--- Toggle the currently selected item.
function ToggleMenuView:toggle_selected()
    local idx = self.state.selected
    local toggles = self.state.toggles
    if idx < 1 or idx > #toggles then return end

    local t = toggles[idx]
    t.value = not t.value
    self:setState({ toggles = toggles })

    if self.props.on_toggle then
        self.props.on_toggle(t.name)
    end
end

---@return string
function ToggleMenuView:__tostring()
    return string.format('ToggleMenuView(%d items)', #self.state.toggles)
end

return ToggleMenuView

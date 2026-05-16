-- Picker: interactive filterable selection list (function component).
-- Uses React-like hooks for state management and declarative VNode rendering.
-- Press / to filter, j/k to navigate, Enter to confirm, Esc/q to close.

local Panel = require 'ide.toolkit.Panel'
local FuzzyScorer = require 'ide.FuzzyScorer'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local Picker = Class('Picker', Panel)

---@param opts { title?: string, items: (string|table)[], on_select: fun(item: any, idx: integer), format?: fun(item: any): string, width?: number, height?: number, auto_search?: boolean }
function Picker:init(opts)
    local max_visible = math.min(#opts.items, 20)
    Panel.init(self, {
        title = opts.title or ' Pick',
        width = opts.width or 0.5,
        height = opts.height or max_visible + 2,
        enter = true,
    })
    self._items = opts.items
    self._on_select = opts.on_select
    self._format = opts.format or function(item)
        return type(item) == 'string' and item or (item.text or item.name or tostring(item))
    end
    self._auto_search = opts.auto_search or false
    self._scorer = FuzzyScorer()

    -- Hook state (managed by component runtime)
    self._component_instance = nil
end

--- The Picker as a function component.
--- Returns a VNode tree describing the UI declaratively.
local function PickerView(props)
    local items = props.items
    local format = props.format
    local scorer = props.scorer
    local width = props.width or 60
    local height = props.height or 20

    -- Reactive state via hooks
    local query, setQuery = hooks.useState('')
    local selected, setSelected = hooks.useState(1)
    local scroll, setScroll = hooks.useState(0)

    -- Memoized filtered list
    local filtered = hooks.useMemo(function()
        if query == '' then return items end
        if scorer and scorer:is_available() then
            return scorer:filter(items, query, format)
        end
        local q = query:lower()
        local result = {}
        for _, item in ipairs(items) do
            if format(item):lower():find(q, 1, true) then
                result[#result + 1] = item
            end
        end
        return result
    end, { query, items })

    -- Store state accessors for external use (keybindings)
    props._state = {
        query = query, setQuery = setQuery,
        selected = selected, setSelected = setSelected,
        scroll = scroll, setScroll = setScroll,
        filtered = filtered,
    }

    -- Clamp selection
    local sel = math.max(1, math.min(selected, #filtered))
    if sel ~= selected then setSelected(sel) end

    -- Auto-scroll
    local list_h = height - 1
    local sc = scroll
    if sel <= sc then sc = sel - 1 end
    if sel > sc + list_h then sc = sel - list_h end
    if sc ~= scroll then setScroll(sc) end

    -- Build VNode tree
    local children = {}

    -- Item rows
    if #filtered == 0 then
        children[#children + 1] = {
            type = 'text',
            text = query ~= '' and ('No matches for "' .. query .. '"') or 'No items',
            indent = 3,
            hl = 'IDEPanelDim',
        }
    else
        for row = 1, list_h do
            local idx = row + sc
            if idx > #filtered then break end
            local item = filtered[idx]
            local text = format(item)
            if idx == sel then
                children[#children + 1] = {
                    type = 'row', hl = 'IDEPanelSelected',
                    children = {
                        { type = 'text', text = '▸ ' .. text, indent = 1, hl = 'IDEPanelSelected' },
                    },
                }
            else
                children[#children + 1] = { type = 'text', text = text, indent = 3, hl = 'IDEPanelNormal' }
            end
        end
    end

    -- Status bar with search query
    local status_text = string.format('%d/%d ', math.min(sel, #filtered), #filtered)
    if query ~= '' then
        status_text = string.format(' %s  %s', query, status_text)
    end
    children[#children + 1] = {
        type = 'status',
        text = status_text,
        hl = 'IDEPanelDim',
        text_hl = 'IDEPanelCounter',
    }

    return children
end

function Picker:_on_mount()
    local picker = self
    local buf = self:buffer()
    local win_obj = self._win
    -- Ignore first Enter to prevent `:IDEActions<CR>` from leaking
    local ready = false
    vim.schedule(function() ready = true end)

    -- Mount the function component
    self._component_instance = C.mount(PickerView, {
        items = self._items,
        format = self._format,
        scorer = self._scorer,
        width = self._current_width or 60,
        height = self._current_height or 20,
        _state = {},
    }, buf, win_obj)

    -- Helper to access reactive state
    local function state()
        return self._component_instance and self._component_instance.ctx.props._state or {}
    end

    -- Navigation
    local function move(delta)
        local s = state()
        if s.setSelected and s.filtered then
            local count = #s.filtered
            if count == 0 then return end
            local new = math.max(1, math.min((s.selected or 1) + delta, count))
            s.setSelected(new)
        end
    end

    self:map('n', 'j', function() move(1) end)
    self:map('n', 'k', function() move(-1) end)
    self:map('n', '<Down>', function() move(1) end)
    self:map('n', '<Up>', function() move(-1) end)
    self:map('n', '<C-d>', function() move(10) end)
    self:map('n', '<C-u>', function() move(-10) end)
    self:map('n', 'G', function()
        local s = state()
        if s.setSelected and s.filtered then s.setSelected(#s.filtered) end
    end)
    self:map('n', 'gg', function()
        local s = state()
        if s.setSelected then s.setSelected(1) end
    end)

    -- Selection
    self:map('n', '<CR>', function()
        if ready then picker:_confirm() end
    end)
    self:map('n', '<2-LeftMouse>', function() picker:_confirm() end)

    -- Filter
    self:map('n', '/', function() picker:_prompt_filter() end)
    self:map('n', '<BS>', function()
        local s = state()
        if s.query and s.query ~= '' and s.setQuery then
            s.setQuery('')
            s.setSelected(1)
        end
    end)

    -- Mouse click
    self:map('n', '<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end
        local win = picker:winid()
        if win and mpos.winid == win then
            local s = state()
            local idx = mpos.line + (s.scroll or 0)
            if idx >= 1 and s.filtered and idx <= #s.filtered then
                s.setSelected(idx)
            end
        end
    end)

    -- Auto-search: printable chars immediately filter the list
    if self._auto_search then
        for byte = 32, 126 do
            local ch = string.char(byte)
            if ch ~= '/' then
                self:map('n', ch, function()
                    local s = state()
                    if s.setQuery then
                        s.setQuery((s.query or '') .. ch)
                        s.setSelected(1)
                    end
                end)
            end
        end
        self:map('n', '<BS>', function()
            local s = state()
            if s.query and s.query ~= '' and s.setQuery then
                s.setQuery(s.query:sub(1, -2))
                s.setSelected(1)
            end
        end)
    end
end

function Picker:_confirm()
    local s = self._component_instance and self._component_instance.ctx.props._state or {}
    local filtered = s.filtered or {}
    local selected = s.selected or 1
    local item = filtered[selected]
    if item and self._on_select then
        self:hide()
        vim.schedule(function()
            self._on_select(item, selected)
        end)
    end
end

function Picker:_prompt_filter()
    local s = self._component_instance and self._component_instance.ctx.props._state or {}
    local query = s.query or ''

    while true do
        if s.setQuery then s.setQuery(query) end
        vim.cmd('redraw')

        local ok, ch = pcall(vim.fn.getcharstr)
        if not ok then break end

        if ch == '\27' then break end
        if ch == '\r' or ch == '\n' then break end
        if ch == '\b' or ch == '\127' or ch == vim.api.nvim_replace_termcodes('<BS>', true, true, true) then
            query = query:sub(1, -2)
        elseif ch == vim.api.nvim_replace_termcodes('<C-u>', true, true, true) then
            query = ''
        elseif #ch == 1 and ch:byte() >= 32 then
            query = query .. ch
        end
    end

    if s.setQuery then s.setQuery(query) end
end

function Picker:hide()
    if self._component_instance then
        C.unmount(self._component_instance)
        self._component_instance = nil
    end
    if self._scorer then self._scorer:destroy() end
    Panel.hide(self)
end

---@return string
function Picker:__tostring()
    return string.format('Picker(%d items)', #self._items)
end

return Picker

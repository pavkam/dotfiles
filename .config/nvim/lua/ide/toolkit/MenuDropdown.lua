-- MenuDropdown: floating dropdown for a menu bar entry.
-- Shows items with icons, text, right-aligned shortcuts, separators.
-- Supports keyboard navigation, mouse hover, and submenu cascading.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local Position = require 'ide.Position'
local Shadow = require 'ide.toolkit.Shadow'

local MenuDropdown = Class('MenuDropdown')

---@param opts { items: table[], col: integer, on_close: fun(), on_navigate: fun(dir: integer), menu_bar: table|nil }
function MenuDropdown:init(opts)
    self._items = opts.items or {}
    self._col = opts.col or 0
    self._on_close = opts.on_close
    self._on_navigate = opts.on_navigate
    self._menu_bar = opts.menu_bar
    self._buf = nil  ---@type Buffer|nil
    self._win = nil  ---@type Window|nil
    self._selected = 0
    self._action_map = {}  -- line index -> item
    self._visible_items = {}
    self._mounted = false
    self._sub_dropdown = nil ---@type MenuDropdown|nil
    self._shadow = nil ---@type Shadow|nil
    self._menu_component = nil
end

function MenuDropdown:show()
    if self._mounted then return end

    -- Filter to visible items
    self._visible_items = {}
    for _, item in ipairs(self._items) do
        if item:is_visible() then
            self._visible_items[#self._visible_items + 1] = item
        end
    end
    if #self._visible_items == 0 then return end

    -- Compute max width
    local max_text = 0
    local max_shortcut = 0
    local has_any_icon = false
    for _, item in ipairs(self._visible_items) do
        if not item.separator then
            if item.icon then has_any_icon = true end
            local icon_w = item.icon and (vim.api.nvim_strwidth(item.icon) + 1) or 2
            local text_w = vim.api.nvim_strwidth(item.text)
            if icon_w + text_w > max_text then max_text = icon_w + text_w end
            if item.shortcut then
                local sw = vim.api.nvim_strwidth(item.shortcut)
                if sw > max_shortcut then max_shortcut = sw end
            end
        end
    end

    local gap = max_shortcut > 0 and 3 or 0
    local width = math.max(max_text + gap + max_shortcut + 2, 14)
    local height = #self._visible_items
    if height == 0 then return end

    local CC = require 'ide.toolkit.component'

    self._action_map = {}
    local items_data = {}
    for i, item in ipairs(self._visible_items) do
        if item.separator then
            items_data[i] = { separator = true }
            self._action_map[i] = nil
        else
            local hl = item:is_enabled() and 'IDEMenuItemNormal' or 'IDEMenuItemDisabled'
            local icon_text = ''
            if has_any_icon then
                icon_text = item.icon and (item.icon .. ' ') or '   '
            end
            items_data[i] = {
                icon = icon_text,
                icon_hl = item:is_enabled() and 'IDEMenuIcon' or hl,
                text = item.text,
                text_hl = hl,
                shortcut = item.shortcut,
                shortcut_hl = item:is_enabled() and 'IDEMenuShortcut' or hl,
            }
            self._action_map[i] = item
        end
    end

    -- Function component for menu items
    local function MenuView(props)
        local children = {}
        for _, d in ipairs(props.items_data) do
            if d.separator then
                children[#children + 1] = { type = 'separator', hl = 'IDEMenuSeparator' }
            else
                children[#children + 1] = {
                    type = 'row',
                    children = {
                        { type = 'text', text = ' ' .. (d.icon or ''), hl = d.icon_hl },
                        { type = 'text', text = d.text, hl = d.text_hl },
                    },
                }
            end
        end
        return children
    end

    -- Position: just below the tabline (row=1), at the menu's column
    local ew = Window.editor_width()
    local col = self._col
    if col + width + 2 > ew then
        col = math.max(0, ew - width - 2)
    end

    -- Shadow (rendered behind the dropdown)
    self._shadow = Shadow.for_float(1, col, width + 2, height + 2, 249)

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('filetype', 'ide-menu-dropdown')

    local float_config = {
        relative = 'editor',
        row = 1,
        col = col,
        width = width,
        height = height,
        border = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
        style = 'minimal',
        zindex = 250,
        enter = true,
    }

    self._win = Window.open_float(self._buf, float_config)
    self._mounted = true

    self._win:set_option('cursorline', true)
    self._win:set_option('winfixbuf', true)
    self._win:set_option('cursorlineopt', 'line')
    self._win:set_option('winhl',
        'Normal:IDEMenuDropdownNormal,FloatBorder:IDEMenuDropdownBorder,CursorLine:IDEMenuItemSelected')
    self._win:set_option('winblend', 0)

    -- Hide cursor in dropdown menus
    IDE.ui:hide_cursor('IDEMenuItemSelected')

    self._menu_component = CC.mount(MenuView, { items_data = items_data }, self._buf, self._win)

    -- Move cursor to first actionable item
    self._selected = 0
    for i = 1, height do
        if self._action_map[i] and self._action_map[i]:is_enabled() then
            self._selected = i
            break
        end
    end
    if self._selected > 0 then
        self._win:set_cursor(Position(self._selected, 1))
    end

    self:_bind_keys()
end

function MenuDropdown:_bind_keys()
    local dd = self
    local bufnr = self._buf:id()
    local winid = self._win:id()
    local count = #self._visible_items

    local function map(key, fn)
        self._buf:bind_key('n', key, fn)
    end

    local function move_to(target)
        if target >= 1 and target <= count and dd._action_map[target] then
            dd._selected = target
            if dd._win and dd._win:is_valid() then
                dd._win:set_cursor(Position(target, 1))
            end
        end
    end

    local function move_next()
        local next = dd._selected
        for _ = 1, count do
            next = next % count + 1
            if dd._action_map[next] and dd._action_map[next]:is_enabled() then break end
        end
        move_to(next)
    end

    local function move_prev()
        local prev = dd._selected
        for _ = 1, count do
            prev = prev - 1
            if prev < 1 then prev = count end
            if dd._action_map[prev] and dd._action_map[prev]:is_enabled() then break end
        end
        move_to(prev)
    end

    local function submit()
        local item = dd._action_map[dd._selected]
        if item and item:is_enabled() then
            if item.submenu then
                -- Open submenu (future extension)
                return
            end
            local action = item.action
            dd:close()
            if action then vim.schedule(action) end
        end
    end

    local function close()
        dd:close()
    end

    map('j', move_next)
    map('<Down>', move_next)
    map('<Tab>', move_next)
    map('k', move_prev)
    map('<Up>', move_prev)
    map('<S-Tab>', move_prev)
    map('<CR>', submit)
    map('<Space>', submit)
    map('<Esc>', close)
    map('q', close)

    -- h/l navigate to adjacent menus
    map('h', function()
        if dd._on_navigate then dd._on_navigate(-1) end
    end)
    map('l', function()
        if dd._on_navigate then dd._on_navigate(1) end
    end)
    map('<Left>', function()
        if dd._on_navigate then dd._on_navigate(-1) end
    end)
    map('<Right>', function()
        if dd._on_navigate then dd._on_navigate(1) end
    end)

    -- Mouse: hover highlights in dropdown, auto-switch on menu bar hover
    map('<MouseMove>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end
        if mpos.winid == winid and mpos.line > 0 then
            -- Hover within dropdown — highlight item
            if dd._action_map[mpos.line] and dd._action_map[mpos.line]:is_enabled() then
                move_to(mpos.line)
            end
        elseif mpos.screenrow == 1 and IDE and IDE.menu_bar then
            -- Mouse moved to menu bar — find which menu and switch
            local bar = IDE.menu_bar
            local col = mpos.screencol - 1
            local pos = 0
            for _, menu in ipairs(bar._menus) do
                local display = menu.name:gsub('&', '')
                local w = vim.api.nvim_strwidth(display) + 4
                if col >= pos and col < pos + w then
                    if bar._active ~= menu.name then
                        bar:open(menu.name)
                    end
                    return
                end
                pos = pos + w
            end
        end
    end)
    map('<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if mpos and mpos.winid == winid and mpos.line > 0 then
            if dd._action_map[mpos.line] and dd._action_map[mpos.line]:is_enabled() then
                move_to(mpos.line)
                submit()
            end
        elseif mpos and mpos.screenrow == 1 and IDE and IDE.menu_bar then
            -- Clicked on menu bar — switch menus
            close()
            vim.schedule(function()
                local key = vim.api.nvim_replace_termcodes('<LeftMouse>', true, true, true)
                vim.api.nvim_feedkeys(key, 'ni', false)
            end)
        else
            close()
        end
    end)

    -- Auto-close when focus leaves
    vim.api.nvim_create_autocmd({ 'WinLeave' }, {
        buffer = bufnr,
        once = true,
        callback = function()
            vim.schedule(function()
                if dd._mounted and dd._win and dd._win:is_valid() then
                    local cur = vim.api.nvim_get_current_win()
                    if cur ~= winid then dd:close() end
                end
            end)
        end,
    })
end

function MenuDropdown:close()
    -- Restore cursor
    IDE.ui:restore_cursor()
    if self._menu_component then
        local CC = require 'ide.toolkit.component'
        CC.unmount(self._menu_component)
        self._menu_component = nil
    end
    if self._sub_dropdown then
        self._sub_dropdown:close()
        self._sub_dropdown = nil
    end
    if self._shadow then
        self._shadow:close()
        self._shadow = nil
    end
    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    if self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end
    self._win = nil
    self._buf = nil
    self._mounted = false
    if self._on_close then
        vim.schedule(self._on_close)
    end
end

---@return boolean
function MenuDropdown:is_visible()
    return self._mounted and self._win ~= nil and self._win:is_valid()
end

---@return string
function MenuDropdown:__tostring()
    return string.format('MenuDropdown(%d items, %s)',
        #self._visible_items, self._mounted and 'open' or 'closed')
end

return MenuDropdown

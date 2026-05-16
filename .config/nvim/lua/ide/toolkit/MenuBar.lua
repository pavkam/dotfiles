-- MenuBar: Turbo Pascal-style top menu bar rendered into vim.o.tabline.
-- Supports &hotkey notation for underlined accelerator keys.
-- Click regions use a single VimScript dispatcher function.

local MenuItem = require 'ide.toolkit.MenuItem'
local MenuDropdown = require 'ide.toolkit.MenuDropdown'

local MenuBar = Class('MenuBar')

-- Create the SINGLE dispatcher VimScript function at module load time.
-- This function exists before any tabline render, so %@ always finds it.
vim.api.nvim_exec2([[
    function! IDE_menu_dispatch(minwid, clicks, button, mods)
        call v:lua.IDE_menu_dispatch_lua(a:minwid)
    endfunction
    function! IDE_tab_dispatch(minwid, clicks, button, mods)
        call v:lua.IDE_tab_dispatch_lua(a:minwid)
    endfunction
]], {})

function MenuBar:init()
    self._menus = {}
    self._menu_index = {}
    self._active = nil
    self._dropdown = nil
    self._contrib = {}

    -- Wire the Lua dispatch handler
    _G.IDE_menu_dispatch_lua = function(menu_idx)
        vim.schedule(function()
            if not IDE or not IDE.menu_bar then return end
            local mb = IDE.menu_bar
            if not mb._menus[menu_idx] then return end
            local name = mb._menus[menu_idx].name
            if mb._active == name then mb:close() else mb:open(name) end
        end)
    end

    _G.IDE_tab_dispatch_lua = function(bufid)
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufid) then
                pcall(function()
                    require('ide.Window').current():set_buffer(require('ide.Buffer')(bufid))
                end)
            end
        end)
    end
end

--- Get display name and hotkey from a name with & notation.
--- "&File" -> display="File", hotkey="F", hotkey_pos=1
---@param name string
---@return string, string|nil, integer|nil  -- display, hotkey char, 1-indexed position
local function parse_hotkey(name)
    local pos = name:find('&')
    if not pos then return name, nil, nil end
    local display = name:sub(1, pos - 1) .. name:sub(pos + 1)
    local hotkey = name:sub(pos + 1, pos + 1)
    return display, hotkey, pos
end

--- Register a top-level menu. Use & before the hotkey letter: "&File", "E&dit"
---@param name string
---@param opts? { key?: string }
---@return MenuBar
function MenuBar:add_menu(name, opts)
    opts = opts or {}
    local display, hotkey = parse_hotkey(name)
    if self._menu_index[display] then return self end
    local entry = { name = name, items = {}, key = opts and opts.key or nil }
    self._menus[#self._menus + 1] = entry
    self._menu_index[name] = #self._menus
    self._menu_index[display] = #self._menus

    -- Auto-register Alt+hotkey keymap from & notation
    if hotkey then
        local bar = self
        local raw_name = name
        vim.keymap.set('n', '<M-' .. hotkey:lower() .. '>', function()
            if bar._active == raw_name then bar:close() else bar:open(raw_name) end
        end, { desc = display .. ' menu', silent = true })
    end

    return self
end

--- Add an item to a menu.
function MenuBar:add_item(menu_name, item)
    local idx = self._menu_index[menu_name]
    if not idx then return self end
    self._menus[idx].items[#self._menus[idx].items + 1] = item
    return self
end

function MenuBar:add_separator(menu_name)
    return self:add_item(menu_name, MenuItem.separator_item())
end

function MenuBar:clear_menu(menu_name)
    local idx = self._menu_index[menu_name]
    if idx then self._menus[idx].items = {} end
    return self
end

function MenuBar:_get_all_items(menu_name)
    local idx = self._menu_index[menu_name]
    if not idx then return {} end
    local items = {}
    for _, item in ipairs(self._menus[idx].items) do items[#items + 1] = item end
    local contrib = self._contrib[menu_name]
    if contrib then
        for _, ext_items in pairs(contrib) do
            if #items > 0 and #ext_items > 0 then
                items[#items + 1] = MenuItem.separator_item()
            end
            for _, item in ipairs(ext_items) do items[#items + 1] = item end
        end
    end
    return items
end

function MenuBar:contribute(menu_name, ext_name, items)
    if not self._contrib[menu_name] then self._contrib[menu_name] = {} end
    self._contrib[menu_name][ext_name] = items
end

function MenuBar:remove_contribution(ext_name)
    for _, contrib in pairs(self._contrib) do contrib[ext_name] = nil end
end

function MenuBar:open(menu_name)
    local idx = self._menu_index[menu_name]
    if not idx then return end

    if self._dropdown and self._dropdown:is_visible() then
        self._dropdown._on_close = nil
        self._dropdown:close()
        self._dropdown = nil
    end

    -- Clear hover state so only the active menu is highlighted
    self._hovered = nil

    -- Store the raw name (with &) for consistent comparison
    local idx2 = self._menu_index[menu_name]
    self._active = idx2 and self._menus[idx2].name or menu_name

    -- Calculate column: sum display widths of menus before this one
    local col = 1
    for i = 1, idx - 1 do
        local display = parse_hotkey(self._menus[i].name)
        col = col + vim.api.nvim_strwidth(display) + 4
    end

    local items = self:_get_all_items(menu_name)
    if #items == 0 then return end

    local bar = self
    self._dropdown = MenuDropdown({
        items = items,
        col = col,
        on_close = function()
            bar._active = nil
            bar._dropdown = nil
            pcall(vim.cmd, 'redrawtabline')
        end,
        on_navigate = function(dir) bar:_navigate(dir) end,
    })
    self._dropdown:show()
    pcall(vim.cmd, 'redrawtabline')
end

function MenuBar:close()
    if self._dropdown and self._dropdown:is_visible() then
        self._dropdown:close()
    end
    self._dropdown = nil
    self._active = nil
    pcall(vim.cmd, 'redrawtabline')
end

function MenuBar:_navigate(dir)
    if not self._active then return end
    local idx = self._menu_index[self._active]
    if not idx then return end
    local new_idx = idx + dir
    if new_idx < 1 then new_idx = #self._menus end
    if new_idx > #self._menus then new_idx = 1 end
    if self._dropdown and self._dropdown:is_visible() then
        self._dropdown._on_close = nil
        self._dropdown:close()
        self._dropdown = nil
    end
    self:open(self._menus[new_idx].name)
end

--- Render the tabline string.
function MenuBar:render()
    local parts = {}
    parts[#parts + 1] = '%#IDEMenuBar#'

    for i, menu in ipairs(self._menus) do
        local display, hotkey, hotkey_pos = parse_hotkey(menu.name)
        local is_active = self._active == menu.name
        -- Only show hover highlight when no dropdown is open
        local is_hovered = not self._active and self._hovered == menu.name
        local hl = is_active and 'IDEMenuActive' or (is_hovered and 'IDEMenuHover' or 'IDEMenuNormal')
        local hotkey_hl = 'IDEMenuHotkey'

        -- Use minwid=i so the dispatcher knows which menu was clicked
        parts[#parts + 1] = '%' .. i .. '@IDE_menu_dispatch@'

        if hotkey_pos and not is_active then
            -- Render with hotkey underline: before + highlighted char + after
            local before = display:sub(1, hotkey_pos - 1)
            local char = display:sub(hotkey_pos, hotkey_pos)
            local after = display:sub(hotkey_pos + 1)
            parts[#parts + 1] = string.format('%%#%s#  %s%%#%s#%s%%#%s#%s  ', hl, before, hotkey_hl, char, hl, after)
        else
            parts[#parts + 1] = string.format('%%#%s#  %s  ', hl, display)
        end

        parts[#parts + 1] = '%X'
    end

    parts[#parts + 1] = '%#IDEMenuBar#%='
    parts[#parts + 1] = '%#IDEMenuBar# '
    return table.concat(parts, '')
end

--- Enable mouse click handling for the menu bar.
--- Uses a global <LeftMouse> mapping to detect clicks on the tabline row.
function MenuBar:enable_mouse()
    local bar = self
    self._hovered = nil

    -- Enable mouse move events for hover tracking
    vim.o.mousemoveevent = true

    -- Calculate column ranges for each menu item
    local function get_menu_at_col(col)
        local pos = 0
        for _, menu in ipairs(bar._menus) do
            local display = parse_hotkey(menu.name)
            local w = vim.api.nvim_strwidth(display) + 4  -- 2 padding each side
            if col >= pos and col < pos + w then
                return menu.name
            end
            pos = pos + w
        end
        return nil
    end

    vim.keymap.set('n', '<LeftMouse>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end

        -- Row 1 = tabline (screenrow is 1-indexed)
        if mpos.screenrow == 1 then
            local menu_name = get_menu_at_col(mpos.screencol - 1)
            if menu_name then
                if bar._active == menu_name then
                    bar:close()
                else
                    bar:open(menu_name)
                end
                return
            end
        end

        -- Check title bar buttons (row 2 = frame border with title)
        if mpos.screenrow == 2 and IDE and IDE._window_chrome then
            -- [■] close button at col 2-4 (after ╔)
            if mpos.screencol >= 2 and mpos.screencol <= 4 then
                IDE._window_chrome:close_current()
                return
            end
            -- [↕] maximize button near right edge
            local cols = vim.o.columns
            if mpos.screencol >= cols - 4 and mpos.screencol <= cols - 2 then
                IDE._window_chrome:toggle_maximize_current()
                return
            end
        end

        -- Not a menu/title click — feed through the normal mouse click
        local key = vim.api.nvim_replace_termcodes('<LeftMouse>', true, true, true)
        vim.api.nvim_feedkeys(key, 'ni', false)
    end, { silent = true, desc = 'Menu bar click handler' })

    -- Hover highlighting + auto-switch when dropdown is open
    vim.keymap.set('n', '<MouseMove>', function()
        local mpos = vim.fn.getmousepos()
        if not mpos then return end
        local old = bar._hovered
        if mpos.screenrow == 1 then
            bar._hovered = get_menu_at_col(mpos.screencol - 1)
        else
            bar._hovered = nil
        end
        if bar._hovered ~= old then
            pcall(vim.cmd, 'redrawtabline')
            -- If a dropdown is open and hover moved to a different menu, switch
            if bar._active and bar._hovered and bar._hovered ~= bar._active then
                bar:open(bar._hovered)
            end
        end
        -- Feed through for other mouse move handling
        local key = vim.api.nvim_replace_termcodes('<MouseMove>', true, true, true)
        vim.api.nvim_feedkeys(key, 'ni', false)
    end, { silent = true, desc = 'Menu bar hover + auto-switch' })
end

function MenuBar:menu_names()
    local names = {}
    for _, m in ipairs(self._menus) do names[#names + 1] = m.name end
    return names
end

function MenuBar:item_count(menu_name) return #self:_get_all_items(menu_name) end
function MenuBar:is_open() return self._active ~= nil end
function MenuBar:active_menu() return self._active end

function MenuBar:__tostring()
    return string.format('MenuBar(%d menus, active=%s)', #self._menus, self._active or 'none')
end

return MenuBar

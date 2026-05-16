-- KeyHint: popup that shows available keymaps for a prefix.
-- Replaces which-key's popup functionality.
-- Uses reactive function component for content rendering.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'
local hooks = require 'ide.toolkit.hooks'
local C = require 'ide.toolkit.component'

local KeyHint = Class('KeyHint')

function KeyHint:init()
    self._groups = {}
    self._panel = nil
end

--- Register a keymap with the hint system.
---@param mode string
---@param lhs string
---@param desc string|nil
---@param icon string|nil
function KeyHint:register(mode, lhs, desc, icon)
    if not desc or desc == '' then return end

    local prefix = lhs:match('^(.-).[^<]*$') or ''
    if #prefix == 0 and #lhs > 1 then
        prefix = lhs:sub(1, #lhs - 1)
    end

    if not self._groups[mode] then self._groups[mode] = {} end
    if not self._groups[mode][prefix] then self._groups[mode][prefix] = {} end

    self._groups[mode][prefix][lhs] = {
        key = lhs:sub(#prefix + 1),
        desc = desc,
        icon = icon,
    }
end

--- Register a group description for a prefix.
---@param mode string
---@param prefix string
---@param desc string
---@param icon string|nil
function KeyHint:register_group(mode, prefix, desc, icon)
    if not self._groups[mode] then self._groups[mode] = {} end
    if not self._groups[mode][prefix] then self._groups[mode][prefix] = {} end
    self._groups[mode][prefix]._group_desc = desc
    self._groups[mode][prefix]._group_icon = icon
end

local function effective_modes(mode)
    if mode == 'v' or mode == 'x' then return { 'v', 'x' } end
    return { mode }
end

--- Function component for key hint content.
local function KeyHintView(props)
    local entries = props.entries or {}
    local max_key_width = props.max_key_width or 4
    local children = {}

    for i, e in ipairs(entries) do
        local icon_text = e.icon and (e.icon .. ' ') or '  '
        local key_text = e.key .. string.rep(' ', max_key_width - vim.api.nvim_strwidth(e.key) + 2)
        children[#children + 1] = {
            type = 'row',
            children = {
                { type = 'text', text = icon_text, hl = 'IDEKeyHintIcon' },
                { type = 'text', text = key_text, hl = 'IDEKeyHintKey' },
                { type = 'text', text = e.desc or '', hl = 'IDEKeyHintDesc' },
            },
        }
    end

    return children
end

--- Show hints for a prefix in the current mode.
---@param prefix string
---@param mode string|nil
function KeyHint:show(prefix, mode)
    mode = mode or vim.fn.mode():sub(1, 1)
    self:dismiss()

    local modes = effective_modes(mode)
    local merged = {}
    local group_desc, group_icon
    for _, m in ipairs(modes) do
        local group = self._groups[m] and self._groups[m][prefix]
        if group then
            for lhs, info in pairs(group) do
                if lhs == '_group_desc' then
                    group_desc = group_desc or info
                elseif lhs == '_group_icon' then
                    group_icon = group_icon or info
                elseif type(info) == 'table' and not merged[lhs] then
                    merged[lhs] = info
                end
            end
        end
    end

    local entries = {}
    for _, info in pairs(merged) do
        entries[#entries + 1] = info
    end
    if #entries == 0 then return end

    table.sort(entries, function(a, b) return a.key < b.key end)

    local max_key_width = 0
    for _, e in ipairs(entries) do
        local kw = vim.api.nvim_strwidth(e.key)
        if kw > max_key_width then max_key_width = kw end
    end

    local title = group_desc and (' ' .. prefix .. ' ' .. group_desc .. ' ') or (' ' .. prefix .. ' ')
    local width = math.max(40, max_key_width + 30)
    local height = math.min(#entries, 20)

    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local row = eh - height - 4
    local col = math.floor((ew - width) / 2)

    local buf = Buffer.create({ listed = false, scratch = true })
    buf:set_option('bufhidden', 'wipe')

    -- Mount reactive component
    local component = C.mount(KeyHintView, {
        entries = entries,
        max_key_width = max_key_width,
    }, buf)

    local win = Window.open_float(buf, {
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        border = { '┌', '─', '┐', '│', '┘', '─', '└', '│' },
        title = { { title, 'IDEDialogTitle' } },
        title_pos = 'center',
        style = 'minimal',
        zindex = 300,
        focusable = false,
    })
    win:set_option('winhl', 'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder')
    win:set_option('winblend', 0)

    self._panel = {
        _buf = buf, _win = win, _component = component,
        is_visible = function() return win:is_valid() end,
        hide = function()
            if component then C.unmount(component) end
            if win:is_valid() then win:close(true) end
            if buf:is_valid() then buf:close(true) end
        end,
    }
end

--- Dismiss the hint popup.
function KeyHint:dismiss()
    if self._panel then
        self._panel:hide()
        self._panel = nil
    end
end

---@return boolean
function KeyHint:is_visible()
    return self._panel ~= nil and self._panel:is_visible()
end

---@return string
function KeyHint:__tostring()
    local count = 0
    for _, groups in pairs(self._groups) do
        for _ in pairs(groups) do count = count + 1 end
    end
    return string.format('KeyHint(%d groups)', count)
end

return KeyHint

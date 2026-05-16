-- MenuItem: value object for menu entries.
-- Represents a single item in a menu bar dropdown — action, separator, or submenu.

local MenuItem = Class('MenuItem')

---@class MenuItemOpts
---@field text string                     -- display text
---@field icon? string                    -- nerd font icon
---@field shortcut? string               -- right-aligned shortcut hint (e.g. '<leader>w')
---@field action? fun()                  -- callback on selection
---@field enabled? fun(): boolean        -- dynamic enabled state (default: always)
---@field visible? fun(): boolean        -- dynamic visibility (default: always)
---@field separator? boolean             -- true = horizontal line, no text
---@field submenu? MenuItem[]            -- nested submenu items

---@param opts MenuItemOpts|nil
function MenuItem:init(opts)
    opts = opts or {}
    self.text = opts.text or ''
    self.icon = opts.icon
    self.shortcut = opts.shortcut
    self.action = opts.action
    self.enabled = opts.enabled
    self.visible = opts.visible
    self.separator = opts.separator or false
    self.submenu = opts.submenu
end

---@return boolean
function MenuItem:is_enabled()
    if self.separator then return false end
    if self.enabled then return self.enabled() end
    return true
end

---@return boolean
function MenuItem:is_visible()
    if self.visible then return self.visible() end
    return true
end

---@return string
function MenuItem:__tostring()
    if self.separator then return 'MenuItem(---)' end
    return string.format('MenuItem(%s)', self.text)
end

--- Convenience: create a separator item.
---@return MenuItem
function MenuItem.separator_item()
    return MenuItem({ separator = true })
end

return MenuItem

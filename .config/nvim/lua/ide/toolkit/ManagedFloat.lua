-- ManagedFloat: lifecycle-managed floating window.
-- Wraps Buffer + Window with mount/unmount, repositioning, z-index, and dismiss policies.
-- Used by FuzzyPicker, CommandLine, message popups, and any transient floating UI.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local ManagedFloat = Class('ManagedFloat')

---@class ManagedFloatOpts
---@field relative? 'editor'|'cursor'|'win'
---@field row? number|string     -- number or '50%'
---@field col? number|string     -- number or '50%'
---@field width? number|string   -- number, fraction (0-1), or 'auto'
---@field height? number|string
---@field border? string|table
---@field title? string
---@field zindex? integer
---@field focusable? boolean
---@field enter? boolean
---@field style? 'minimal'
---@field buf? Buffer            -- existing buffer to reuse
---@field buf_options? table
---@field win_options? table
---@field dismiss? { keys?: string[], on_leave?: boolean }

---@param opts ManagedFloatOpts
function ManagedFloat:init(opts)
    opts = opts or {}
    self._opts = opts
    self._buf = opts.buf or nil
    self._win = nil
    self._mounted = false
    self._owns_buf = not opts.buf
end

--- Resolve a dimension spec to pixels.
---@param spec number|string
---@param total integer
---@return integer
local function resolve_dim(spec, total)
    if type(spec) == 'string' and spec:match('%%$') then
        return math.floor(total * tonumber(spec:sub(1, -2)) / 100)
    elseif type(spec) == 'number' and spec <= 1 and spec > 0 then
        return math.floor(total * spec)
    elseif type(spec) == 'number' then
        return math.floor(spec)
    end
    return 40
end

function ManagedFloat:_build_config()
    local ew = Window.editor_width()
    local eh = Window.editor_height()
    local o = self._opts

    local w = resolve_dim(o.width or 0.6, ew)
    local h = resolve_dim(o.height or 0.4, eh)
    local row = resolve_dim(o.row or '50%', eh) - math.floor(h / 2)
    local col = resolve_dim(o.col or '50%', ew) - math.floor(w / 2)

    row = math.max(0, math.min(row, eh - h - 2))
    col = math.max(0, math.min(col, ew - w - 2))

    local config = {
        relative = o.relative or 'editor',
        row = row,
        col = col,
        width = math.max(1, w),
        height = math.max(1, h),
        border = o.border or 'rounded',
        style = o.style or 'minimal',
        zindex = o.zindex or 50,
        focusable = o.focusable ~= false,
        enter = o.enter or false,
    }

    if o.title and o.title ~= '' then
        config.title = ' ' .. o.title .. ' '
        config.title_pos = 'center'
    end

    return config
end

--- Mount the floating window (create if needed).
function ManagedFloat:mount()
    if self._mounted then return end

    if not self._buf then
        self._buf = Buffer.create({ listed = false, scratch = true })
        self._buf:set_option('bufhidden', 'hide')
        self._owns_buf = true
    end

    if self._opts.buf_options then
        for k, v in pairs(self._opts.buf_options) do
            self._buf:set_option(k, v)
        end
    end

    local config = self:_build_config()
    self._win = Window.open_float(self._buf, config)
    self._mounted = true

    if self._opts.win_options then
        for k, v in pairs(self._opts.win_options) do
            self._win:set_option(k, v)
        end
    end

    -- Default window options
    self._win:set_option('number', false)
    self._win:set_option('relativenumber', false)
    self._win:set_option('signcolumn', 'no')
    self._win:set_option('wrap', false)

    -- Dismiss policies
    local dismiss = self._opts.dismiss or {}
    if dismiss.keys then
        for _, key in ipairs(dismiss.keys) do
            self._buf:bind_key('n', key, function() self:unmount() end)
        end
    end

    if dismiss.on_leave then
        local mf = self
        local winid = self._win:id()
        vim.api.nvim_create_autocmd('WinLeave', {
            buffer = self._buf:id(),
            once = true,
            callback = function()
                vim.schedule(function()
                    if mf._mounted and vim.api.nvim_get_current_win() ~= winid then
                        mf:unmount()
                    end
                end)
            end,
        })
    end
end

--- Hide without destroying the buffer (can remount later).
function ManagedFloat:hide()
    if not self._mounted then return end
    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    self._win = nil
    self._mounted = false
end

--- Show after hiding (remount with same buffer).
function ManagedFloat:show()
    if self._mounted then return end
    if not self._buf or not self._buf:is_valid() then return end

    local config = self:_build_config()
    config.enter = true
    self._win = Window.open_float(self._buf, config)
    self._mounted = true

    -- Re-register on_leave autocmd (the previous one was `once = true`)
    local dismiss = self._opts.dismiss or {}
    if dismiss.on_leave and self._buf:is_valid() then
        local mf = self
        local winid = self._win:id()
        vim.api.nvim_create_autocmd('WinLeave', {
            buffer = self._buf:id(),
            once = true,
            callback = function()
                vim.schedule(function()
                    if mf._mounted and vim.api.nvim_get_current_win() ~= winid then
                        mf:unmount()
                    end
                end)
            end,
        })
    end
end

--- Destroy the window and buffer, clean up everything.
function ManagedFloat:unmount()
    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    if self._owns_buf and self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end
    self._win = nil
    self._buf = nil
    self._mounted = false
end

--- Update position/size without remounting.
---@param layout { row?: number, col?: number, width?: number, height?: number }
function ManagedFloat:update_layout(layout)
    if not self._mounted or not self._win or not self._win:is_valid() then return end
    for k, v in pairs(layout) do
        self._opts[k] = v
    end
    local config = self:_build_config()
    self._win:update_config(config)
end

--- Set buffer content.
---@param lines string[]
function ManagedFloat:set_lines(lines)
    if not self._buf or not self._buf:is_valid() then return end
    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, lines)
    self._buf:set_option('modifiable', false)
end

--- Get the underlying Window (only valid when mounted).
---@return Window|nil
function ManagedFloat:window()
    return self._mounted and self._win or nil
end

--- Get the underlying Buffer.
---@return Buffer|nil
function ManagedFloat:buffer()
    return self._buf
end

---@return boolean
function ManagedFloat:is_visible()
    return self._mounted and self._win ~= nil and self._win:is_valid()
end

---@return string
function ManagedFloat:__tostring()
    return string.format('ManagedFloat(%s)', self._mounted and 'mounted' or 'unmounted')
end

return ManagedFloat

-- WindowList: collection of Window objects with lifecycle tracking.
--
-- Events: 'enter', 'leave', 'open', 'close'

local EventEmitter = require 'ide.EventEmitter'

local WindowList = Class('WindowList')
Class.include(WindowList, EventEmitter)

function WindowList:init()
    self._cache = {} ---@type table<integer, Window>
end

--- Get or create a Window wrapper.
---@param id integer
---@return Window|nil
function WindowList:get(id)
    if not vim.api.nvim_win_is_valid(id) then
        self._cache[id] = nil
        return nil
    end

    if not self._cache[id] then
        local Window = require 'ide.Window'
        self._cache[id] = Window.get(id)
    end

    return self._cache[id]
end

--- The current window.
---@return Window
function WindowList:current()
    local win = self:get(vim.api.nvim_get_current_win())
    if not win then
        local Window = require 'ide.Window'
        return Window.get(vim.api.nvim_get_current_win()) or Window(vim.api.nvim_get_current_win())
    end
    return win
end

--- All valid windows.
---@return Window[]
function WindowList:all()
    local result = {}
    for _, id in ipairs(vim.api.nvim_list_wins()) do
        local win = self:get(id)
        if win then
            table.insert(result, win)
        end
    end
    return result
end

--- Iterator over all valid windows.
---@return fun(): Window|nil
function WindowList:iter()
    local windows = self:all()
    local i = 0
    return function()
        i = i + 1
        return windows[i]
    end
end

---@return integer
function WindowList:count()
    return #self:all()
end

--- Wire up autocommands for window lifecycle.
function WindowList:_wire_events()
    vim.api.nvim_create_autocmd('WinEnter', {
        callback = function()
            local win = self:current()
            win:emit('enter')
            self:emit('enter', win)
        end,
    })

    vim.api.nvim_create_autocmd('WinLeave', {
        callback = function()
            local win_id = vim.api.nvim_get_current_win()
            local win = self._cache[win_id]
            if win then
                win:emit('leave')
                self:emit('leave', win)
            end
        end,
    })

    vim.api.nvim_create_autocmd('WinNew', {
        callback = function()
            local win = self:current()
            self:emit('open', win)
        end,
    })

    vim.api.nvim_create_autocmd('WinClosed', {
        callback = function(args)
            local win_id = tonumber(args.match)
            if win_id then
                local Window = require 'ide.Window'
                Window._evict(win_id)
                local win = self._cache[win_id]
                if win then
                    self:emit('close', win)
                    self._cache[win_id] = nil
                end
            end
        end,
    })
end

---@return string
function WindowList:__tostring()
    return string.format('WindowList(%d windows)', self:count())
end

return WindowList

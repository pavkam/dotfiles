-- Splitter: manages multiple FramedWindows in a tiled layout.
-- Handles horizontal and vertical splits, resize, and focus cycling.
-- This is the foundation for multi-window support in the FramedWindow system.

local FramedWindow = require 'ide.FramedWindow'

local Splitter = Class('Splitter')

---@class SplitterOpts
---@field direction 'horizontal'|'vertical'
---@field ratio? number # 0-1, split ratio (default 0.5)

---@param opts? SplitterOpts
function Splitter:init(opts)
    opts = opts or {}
    self._direction = opts.direction or 'vertical'
    self._ratio = opts.ratio or 0.5
    self._frames = {} ---@type FramedWindow[]
    self._active = 1
end

--- Add a FramedWindow to the splitter.
---@param frame FramedWindow
function Splitter:add(frame)
    self._frames[#self._frames + 1] = frame
    frame:set_number(#self._frames)
end

--- Get the active frame.
---@return FramedWindow|nil
function Splitter:active_frame()
    return self._frames[self._active]
end

--- Cycle focus to the next frame.
function Splitter:cycle(dir)
    if #self._frames <= 1 then return end
    self._active = self._active + (dir or 1)
    if self._active > #self._frames then self._active = 1 end
    if self._active < 1 then self._active = #self._frames end

    local frame = self._frames[self._active]
    if frame and frame:is_valid() then
        vim.api.nvim_set_current_win(frame:window_id())
    end
end

--- Layout all frames within a given area.
---@param row integer
---@param col integer
---@param width integer
---@param height integer
function Splitter:layout(row, col, width, height)
    if #self._frames == 0 then return end

    if #self._frames == 1 then
        self._frames[1]:set_layout(row, col, width, height)
        return
    end

    if self._direction == 'vertical' then
        -- Each frame border takes 2 cols (left+right). Gap between frames = 0 (borders touch).
        -- Total: left_content + 2 + right_content + 2 = width + 2 (outer border of parent area)
        local left_w = math.floor((width - 2) * self._ratio)
        local right_w = width - 2 - left_w
        for i, frame in ipairs(self._frames) do
            if i == 1 then
                frame:set_layout(row, col, left_w, height)
            elseif i == 2 then
                -- Right frame starts after left frame's full visual width (content + 2 for border)
                frame:set_layout(row, col + left_w + 2, right_w, height)
            end
        end
    else
        local top_h = math.floor((height - 2) * self._ratio)
        local bot_h = height - 2 - top_h
        for i, frame in ipairs(self._frames) do
            if i == 1 then
                frame:set_layout(row, col, width, top_h)
            elseif i == 2 then
                frame:set_layout(row + top_h + 2, col, width, bot_h)
            end
        end
    end
end

--- Set the split ratio.
---@param ratio number # 0-1
function Splitter:set_ratio(ratio)
    self._ratio = math.max(0.1, math.min(0.9, ratio))
end

--- Resize by delta.
---@param delta number # positive = grow first pane, negative = shrink
function Splitter:resize(delta)
    self:set_ratio(self._ratio + delta)
end

--- Close a specific frame.
---@param index integer
function Splitter:close_frame(index)
    local frame = self._frames[index]
    if frame then
        frame:close()
        table.remove(self._frames, index)
        -- Re-number remaining frames
        for i, f in ipairs(self._frames) do
            f:set_number(i)
        end
        if self._active > #self._frames then
            self._active = math.max(1, #self._frames)
        end
    end
end

--- Close all frames.
function Splitter:close_all()
    for _, frame in ipairs(self._frames) do
        frame:close()
    end
    self._frames = {}
    self._active = 1
end

--- Get frame count.
function Splitter:count()
    return #self._frames
end

function Splitter:__tostring()
    return string.format('Splitter(%s, %d frames, ratio=%.2f)',
        self._direction, #self._frames, self._ratio)
end

return Splitter

-- Shadow: TurboVision-style drop shadow for floating windows.
-- Creates a semi-transparent dark rectangle offset below/right of the parent.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Shadow = Class('Shadow')

---@param opts { row: integer, col: integer, width: integer, height: integer, zindex?: integer }
function Shadow:init(opts)
    self._row = opts.row
    self._col = opts.col
    self._width = opts.width
    self._height = opts.height
    self._zindex = opts.zindex or 199
    self._buf = nil
    self._win = nil
end

function Shadow:show()
    if self._win and self._win:is_valid() then return end

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')

    local lines = {}
    for _ = 1, self._height do
        lines[#lines + 1] = string.rep(' ', self._width)
    end
    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, lines)
    self._buf:set_option('modifiable', false)

    self._win = Window.open_float(self._buf, {
        relative = 'editor',
        row = self._row + 1,
        col = self._col + 2,
        width = self._width,
        height = self._height,
        border = 'none',
        style = 'minimal',
        zindex = self._zindex,
        focusable = false,
    })

    if self._win and self._win:is_valid() then
        self._win:set_option('winhl', 'Normal:IDEDialogShadow')
        self._win:set_option('winblend', 30)
    end
end

function Shadow:close()
    if self._win and self._win:is_valid() then
        self._win:close(true)
    end
    if self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end
    self._win = nil
    self._buf = nil
end

function Shadow:is_visible()
    return self._win ~= nil and self._win:is_valid()
end

--- Create and show a shadow for a given window position and size.
---@param row integer
---@param col integer
---@param width integer
---@param height integer
---@param zindex? integer
---@return Shadow
function Shadow.for_float(row, col, width, height, zindex)
    local s = Shadow({
        row = row,
        col = col,
        width = width,
        height = height,
        zindex = zindex,
    })
    s:show()
    return s
end

function Shadow:__tostring()
    return string.format('Shadow(%dx%d at %d,%d)', self._width, self._height, self._row, self._col)
end

return Shadow

-- Tooltip: TurboVision-style hover popup for LSP hover/signature.
-- Positioned near cursor, auto-dismisses on cursor move.

local Buffer = require 'ide.Buffer'
local Window = require 'ide.Window'

local Tooltip = Class('Tooltip')

---@param opts { content: string|string[], max_width?: integer, border?: boolean }
function Tooltip:init(opts)
    self._content = type(opts.content) == 'string' and vim.split(opts.content, '\n') or opts.content
    self._max_width = opts.max_width or 80
    self._border = opts.border ~= false
    self._buf = nil
    self._win = nil
end

function Tooltip:show()
    if self._win and self._win:is_valid() then return end

    local lines = self._content
    local max_w = 0
    for _, l in ipairs(lines) do
        local w = vim.api.nvim_strwidth(l)
        if w > max_w then max_w = w end
    end
    local width = math.min(max_w + 2, self._max_width)
    local height = math.min(#lines, 20)

    self._buf = Buffer.create({ listed = false, scratch = true })
    self._buf:set_option('bufhidden', 'wipe')
    self._buf:set_option('modifiable', true)
    self._buf:set_lines(0, -1, lines)
    self._buf:set_option('modifiable', false)
    self._buf:set_option('filetype', 'markdown')

    local border = self._border
        and { '┌', '─', '┐', '│', '┘', '─', '└', '│' }
        or 'none'

    self._win = Window.open_float(self._buf, {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = width,
        height = height,
        border = border,
        style = 'minimal',
        zindex = 250,
        focusable = false,
    })

    self._win:set_option('winhl', 'Normal:IDEDialogNormal,FloatBorder:IDEDialogBorder')
    self._win:set_option('wrap', true)
    self._win:set_option('winblend', 0)

    -- Auto-dismiss on cursor move (buffer-scoped, auto-cleaned by Neovim on BufDelete)
    local tt = self
    local dismiss_id = vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave' }, {
        once = true,
        callback = function()
            vim.schedule(function() tt:close() end)
        end,
    })
    self._dismiss_autocmd = dismiss_id
end

function Tooltip:close()
    if self._dismiss_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._dismiss_autocmd)
        self._dismiss_autocmd = nil
    end
    if self._win and self._win:is_valid() then self._win:close(true) end
    if self._buf and self._buf:is_valid() then self._buf:close(true) end
    self._win = nil
    self._buf = nil
end

function Tooltip:__tostring()
    return string.format('Tooltip(%d lines)', #self._content)
end

return Tooltip

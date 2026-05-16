-- VirtualText: managed extmark-based virtual text with lifecycle.
-- Provides show/hide/update/destroy for inline annotations, ghost text, diagnostics suffixes.

local Buffer = require 'ide.Buffer'

local VirtualText = Class('VirtualText')

local _ns = vim.api.nvim_create_namespace('ide_virtual_text')

---@class VirtualTextOpts
---@field line integer          -- 0-indexed line number
---@field text string           -- display text
---@field hl? string            -- highlight group
---@field position? 'eol'|'overlay'|'right_align'|'inline'
---@field priority? integer

---@param buf Buffer
---@param opts VirtualTextOpts
function VirtualText:init(buf, opts)
    self._buf = buf
    self._line = opts.line
    self._text = opts.text
    self._hl = opts.hl or 'Comment'
    self._position = opts.position or 'eol'
    self._priority = opts.priority or 10
    self._mark_id = nil
end

function VirtualText:show()
    if self._mark_id then self:hide() end
    if not self._buf:is_valid() then return end

    local virt_text_pos = self._position
    if virt_text_pos == 'inline' then virt_text_pos = 'inline' end

    self._mark_id = self._buf:set_extmark(_ns, self._line, 0, {
        virt_text = { { self._text, self._hl } },
        virt_text_pos = virt_text_pos,
        priority = self._priority,
    })
end

function VirtualText:hide()
    if self._mark_id and self._buf:is_valid() then
        pcall(vim.api.nvim_buf_del_extmark, self._buf:id(), _ns, self._mark_id)
    end
    self._mark_id = nil
end

---@param opts { text?: string, hl?: string, line?: integer }
function VirtualText:update(opts)
    if opts.text then self._text = opts.text end
    if opts.hl then self._hl = opts.hl end
    if opts.line then self._line = opts.line end
    if self._mark_id then
        self:hide()
        self:show()
    end
end

function VirtualText:destroy()
    self:hide()
    self._buf = nil
end

---@return boolean
function VirtualText:is_visible()
    return self._mark_id ~= nil
end

---@return string
function VirtualText:__tostring()
    return string.format('VirtualText(%s, %s)', self._text, self:is_visible() and 'visible' or 'hidden')
end

return VirtualText

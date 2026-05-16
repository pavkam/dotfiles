-- InputField: embeddable text input component.
-- Used by FuzzyPicker (prompt), CommandLine (cmdline), and anywhere inline text input is needed.
-- Creates a prompt buffer and tracks keystrokes via on_lines callback.

local Buffer = require 'ide.Buffer'

local InputField = Class('InputField')

---@class InputFieldOpts
---@field prompt? string         -- prompt prefix (e.g. '> ')
---@field on_change? fun(text: string)  -- called on every keystroke
---@field on_submit? fun(text: string)  -- called on <CR>
---@field on_cancel? fun()              -- called on <Esc>
---@field initial? string               -- initial text

---@param opts InputFieldOpts
function InputField:init(opts)
    opts = opts or {}
    self._prompt = opts.prompt or '> '
    self._on_change = opts.on_change
    self._on_submit = opts.on_submit
    self._on_cancel = opts.on_cancel
    self._initial = opts.initial or ''
    self._buf = nil
    self._attached = false
    self._focused = false
end

--- Create the input buffer and start listening.
---@return Buffer
function InputField:create_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'prompt'
    vim.fn.prompt_setprompt(buf, self._prompt)

    if self._on_submit then
        vim.fn.prompt_setcallback(buf, function(text)
            self._on_submit(text)
        end)
    end

    self._buf = Buffer.get(buf)

    -- Set initial text
    if self._initial ~= '' then
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_set_text(buf, 0, #self._prompt, 0, #self._prompt, { self._initial })
            end
        end)
    end

    -- Track text changes for on_change
    if self._on_change then
        local field = self
        vim.api.nvim_buf_attach(buf, false, {
            on_lines = function()
                vim.schedule(function()
                    if not vim.api.nvim_buf_is_valid(buf) then return end
                    local text = field:get_text()
                    if field._on_change then field._on_change(text) end
                end)
                return false
            end,
        })
        self._attached = true
    end

    -- Cancel on Esc / C-c
    if self._on_cancel then
        self._buf:bind_key('i', '<Esc>', function() self._on_cancel() end)
        self._buf:bind_key('i', '<C-c>', function() self._on_cancel() end)
    end

    return self._buf
end

--- Get the current input text (without the prompt prefix).
---@return string
function InputField:get_text()
    if not self._buf or not self._buf:is_valid() then return '' end
    local line = vim.api.nvim_buf_get_lines(self._buf:id(), 0, 1, false)[1] or ''
    if line:sub(1, #self._prompt) == self._prompt then
        return line:sub(#self._prompt + 1)
    end
    return line
end

--- Set the input text programmatically.
---@param text string
function InputField:set_text(text)
    if not self._buf or not self._buf:is_valid() then return end
    local buf = self._buf:id()
    local prompt_len = #self._prompt
    vim.api.nvim_buf_set_text(buf, 0, prompt_len, 0, -1, { text })
end

--- Get the underlying buffer.
---@return Buffer|nil
function InputField:buffer()
    return self._buf
end

--- Focus the input field (enter insert mode).
function InputField:focus()
    if self._buf and self._buf:is_valid() then
        vim.cmd.startinsert({ bang = true })
    end
end

--- Destroy the input field.
function InputField:destroy()
    if self._buf and self._buf:is_valid() then
        self._buf:close(true)
    end
    self._buf = nil
    self._attached = false
end

--- Render the input field as a bordered widget for embedding in Dialog.
--- Returns text + highlights for the TurboVision single-line border look.
---@param width integer # total width including border
---@return string[], table[] # lines (3: top border, content, bottom border), highlights per line
function InputField:render_bordered(width)
    local inner_w = width - 2
    local text = self:get_text()
    local display = text .. '▏'
    if #display < inner_w then display = display .. string.rep(' ', inner_w - #display) end
    if #display > inner_w then display = display:sub(1, inner_w) end

    local top = '┌' .. string.rep('─', inner_w) .. '┐'
    local mid = '│' .. display .. '│'
    local bot = '└' .. string.rep('─', inner_w) .. '┘'

    local highlights = {
        { { group = 'IDEDialogBorder', col_start = 0, col_end = #top } },
        { { group = 'IDEDialogFocused', col_start = 1, col_end = 1 + #display } },
        { { group = 'IDEDialogBorder', col_start = 0, col_end = #bot } },
    }

    return { top, mid, bot }, highlights
end

--- Render the input field as a single-line text + highlights for Dialog embedding.
---@return string, table[] # rendered text, highlight spans
function InputField:render()
    local text = self:get_text()
    local display = '│' .. self._prompt .. text .. '▏│'

    local hl_group = self._focused and 'IDEDialogFocused' or 'IDEDialogNormal'
    local highlights = {
        { group = 'IDEDialogBorder', col_start = 0, col_end = #'│' },
        { group = hl_group, col_start = #'│', col_end = #display - #'│' },
        { group = 'IDEDialogBorder', col_start = #display - #'│', col_end = #display },
    }

    return display, highlights
end

--- Check if this is focusable (for Dialog tab cycling).
function InputField:focusable() return true end
function InputField:on_focus() self._focused = true end
function InputField:on_blur() self._focused = false end
function InputField:on_activate() self:focus() end
function InputField:label() return '' end

---@return string
function InputField:__tostring()
    return string.format('InputField(%s)', self._prompt)
end

return InputField

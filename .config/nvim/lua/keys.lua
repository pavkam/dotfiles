local icons = require 'icons'
local events = require 'events'

---@class core.keys
local M = {}

---@alias core.keys.KeyMapMode 'n' | 'v' | 'V' | 'c' | 's' | 'x' | 'i' | 'o' | 't' # the mode to map the key in
---@alias core.keys.EnableKeyCondFunc fun(buffer: integer): boolean # the condition to check before enabling the key

---@class (exact) core.keys.KeyMapOpts # the options to pass to the keymap
---@field buffer integer|nil # whether the keymap is buffer-local
---@field silent boolean|nil # whether the keymap is silent
---@field expr boolean|nil # whether the keymap is an expression
---@field noremap boolean|nil # whether the keymap is non-recursive
---@field nowait boolean|nil # whether the keymap is nowait
---@field desc string|nil # the description of the keymap
---@field icon string|nil # the icon of the keymap

--- Maps a key to an action
--- @param mode core.keys.KeyMapMode|core.keys.KeyMapMode[] # the mode(s) to map the key in
--- @param key string # the key to map
--- @param action string|function # the action to map the key to
--- @param opts core.keys.KeyMapOpts|nil # the options to pass to the keymap
function M.map(mode, key, action, opts)
    opts = opts or {}

    if ide.plugins.has 'which-key.nvim' and mode ~= 'c' then
        local wk = require 'which-key'
        wk.add {
            key,
            action,
            desc = opts.desc,
            icon = opts.icon,
            silent = opts.silent,
            expr = opts.expr,
            noremap = opts.noremap,
            nowait = opts.nowait,
            buffer = opts.buffer,
            mode = mode,
        }
    else
        vim.keymap.set(mode, key, action, {
            silent = opts.silent,
            expr = opts.expr,
            noremap = opts.noremap,
            nowait = opts.nowait,
            buffer = opts.buffer,
            desc = opts.icon and icons.iconify(opts.icon, opts.desc) or opts.desc,
        })
    end
end

---@class (exact) core.keys.KeyGroupOpts # the options to pass to the key group
---@field lhs string # the key to decorate
---@field icon string|nil # the icon of the key group
---@field desc string|nil # the description of the key group
---@field buffer integer|nil # whether the key group is buffer-local
---@field mode core.keys.KeyMapMode|core.keys.KeyMapMode[] # the mode(s) to map the key group in

--- Registers a key group
---@param opts core.keys.KeyGroupOpts # the options to pass to the key group
function M.group(opts)
    local using_which_key = package.loaded['lazy'] and require('lazy.core.config').spec.plugins['which-key.nvim'] ~= nil

    if using_which_key then
        local wk = require 'which-key'
        wk.add { opts.lhs, mode = opts.mode, icon = opts.icon, group = opts.desc, buffer = opts.buffer }
    end
end

---@alias core.keys.KeyMapCallback
---| fun(mode: core.keys.KeyMapMode|core.keys.KeyMapMode[], lhs" string, rhs:string|function, opts:core.keys.KeyMapOpts)

--- Allows attaching keymaps in a given buffer alone.
---@param file_types string|table|nil # the list of file types to attach the keymaps to
---@param callback fun(set: core.keys.KeyMapCallback, file_type: string, buffer: integer) # the callback to call
---when the event is triggered
---@param force boolean|nil # whether to force the keymaps to be set even if they are already set
---@return number # the group id of the created group
function M.attach(file_types, callback, force)
    assert(type(callback) == 'function')

    if file_types == nil then
        file_types = '*'
    else
        file_types = table.to_list(file_types)
    end

    return events.on_event('FileType', function(evt)
        if file_types == '*' and vim.buf.is_special(evt.buf) then
            return
        end

        ---@type core.keys.KeyMapCallback
        local mapper = function(mode, lhs, rhs, opts)
            ---@diagnostic disable-next-line: param-type-mismatch
            local has_mapping = not vim.tbl_isempty(vim.fn.maparg(lhs, mode, 0, 1))
            if not has_mapping or force then
                M.map(mode, lhs, rhs, table.merge({ buffer = evt.buf }, opts or {}))
            end
        end

        callback(mapper, evt.match, evt.buf)
    end, file_types)
end

--- Feed keys to Neovim
---@param keys string # the keys to feed
---@param mode string|nil # the mode to feed the keys in
function M.feed(keys, mode)
    assert(type(keys) == 'string')
    mode = mode or 'n'

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), mode, false)
end

--- Formats the term_codes to be human-readable
---@param str string # the string to format
---@return string # the formatted string
function M.format_term_codes(str)
    assert(type(str) == 'string')

    local sub = str:gsub(string.char(9), '<TAB>'):gsub('', '<C-F>'):gsub(' ', '<Space>'):gsub('\n', '<CR>')
    return sub
end

return M

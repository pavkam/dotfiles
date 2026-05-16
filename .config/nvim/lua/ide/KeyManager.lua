-- KeyManager: keymap registration abstraction.
-- Owns all keymap registration. Uses the KeyHint toolkit component
-- to show available keymaps when a prefix key is paused on.

local KeyHint = require 'ide.toolkit.KeyHint'

local KeyManager = Class('KeyManager')

function KeyManager:init()
    self._maps = {}
    self._hint = KeyHint()

    local Highlight = require 'ide.Highlight'
    Highlight('IDEKeyHintKey'):fg('#7dcfff'):bold():as_default():define()
    Highlight('IDEKeyHintDesc'):fg('#c0caf5'):as_default():define()
    Highlight('IDEKeyHintIcon'):fg('#bb9af7'):as_default():define()
end

--- Get the key hint system for displaying available keymaps.
---@return KeyHint
function KeyManager:hints()
    return self._hint
end

--- Map a key to an action.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts { desc?: string, icon?: string, buffer?: integer, silent?: boolean, expr?: boolean, noremap?: boolean, nowait?: boolean }|nil
---@return KeyManager
function KeyManager:map(mode, lhs, rhs, opts)
    opts = opts or {}

    if opts.buffer and not vim.api.nvim_buf_is_valid(opts.buffer) then
        return self
    end

    vim.keymap.set(mode, lhs, rhs, {
        desc = opts.desc,
        silent = opts.silent ~= false,
        expr = opts.expr,
        noremap = opts.noremap,
        nowait = opts.nowait,
        buffer = opts.buffer,
    })

    local modes = type(mode) == 'table' and mode or { mode }
    for _, m in ipairs(modes) do
        self._hint:register(m, lhs, opts.desc, opts.icon)
    end

    table.insert(self._maps, {
        mode = mode, lhs = lhs, rhs = rhs, opts = opts
    })

    return self
end

--- Register a key group (prefix label).
---@param lhs string
---@param opts { desc?: string, icon?: string, mode?: string|string[], buffer?: integer }|nil
---@return KeyManager
function KeyManager:group(lhs, opts)
    opts = opts or {}
    local modes = type(opts.mode) == 'table' and opts.mode or { opts.mode or 'n' }
    for _, m in ipairs(modes) do
        self._hint:register_group(m, lhs, opts.desc or '', opts.icon)
    end
    return self
end

--- Attach keymaps to a specific filetype.
---@param filetype string|string[]
---@param fn fun(set: fun(mode: string|string[], lhs: string, rhs: string|function, opts: table|nil))
---@param use_buffer boolean|nil
function KeyManager:attach(filetype, fn, use_buffer)
    local filetypes = type(filetype) == 'string' and { filetype } or filetype
    local attached_bufs = {}

    local id = vim.api.nvim_create_autocmd('FileType', {
        pattern = filetypes,
        callback = function(args)
            if attached_bufs[args.buf] then return end
            attached_bufs[args.buf] = true
            local self_ref = self
            fn(function(mode, lhs, rhs, opts)
                opts = opts or {}
                if use_buffer then
                    opts.buffer = args.buf
                end
                self_ref:map(mode, lhs, rhs, opts)
            end)
        end,
    })
    return function() pcall(vim.api.nvim_del_autocmd, id) end
end

--- Show key hints for a prefix.
---@param prefix string
---@param mode string|nil
function KeyManager:show_hints(prefix, mode)
    self._hint:show(prefix, mode)
end

--- Dismiss key hints.
function KeyManager:dismiss_hints()
    self._hint:dismiss()
end

--- Enable auto-show hints after prefix key timeout.
--- Intercepts the leader key to show hints if no continuation arrives.
--- Also registers visual mode hint triggers for textobject and navigation prefixes.
function KeyManager:enable_auto_hints()
    if self._auto_hints_enabled then return end
    self._auto_hints_enabled = true
    local km = self

    -- F1 toggles key hints (always available)
    vim.keymap.set('n', '<F1>', function()
        if km._hint:is_visible() then
            km:dismiss_hints()
        else
            km:show_hints('<leader>', 'n')
        end
    end, { desc = 'Toggle key hints', silent = true })

    -- F1 in visual mode shows visual-mode leader hints
    vim.keymap.set('v', '<F1>', function()
        if km._hint:is_visible() then
            km:dismiss_hints()
        else
            km:show_hints('<leader>', 'x')
        end
    end, { desc = 'Toggle key hints', silent = true })

    -- Dismiss hints on any key press (namespaced to avoid accumulation)
    local ns = vim.api.nvim_create_namespace('ide_key_hints')
    vim.on_key(function(key)
        if km._hint:is_visible() then
            vim.schedule(function() km:dismiss_hints() end)
        end
    end, ns)

    -- Register visual mode textobject groups
    self:group('a', { desc = 'Around', mode = { 'x', 'o' } })
    self:group('i', { desc = 'Inside', mode = { 'x', 'o' } })
end

--- Convert a key notation string (e.g. '<CR>', '<Esc>') to internal terminal codes.
---@param key string
---@return string
function KeyManager:termcodes(key)
    return vim.api.nvim_replace_termcodes(key, true, true, true)
end

--- Send key sequence programmatically.
---@param keys string
---@param mode? string # default 'm'
function KeyManager:feed(keys, mode)
    vim.api.nvim_feedkeys(keys, mode or 'm', false)
end

--- Execute a normal mode command.
---@param cmd string
function KeyManager:normal(cmd)
    vim.cmd('normal! ' .. cmd)
end

--- Check if the popup completion menu is visible.
---@return boolean
function KeyManager:popup_visible()
    return vim.fn.pumvisible() == 1
end

---@return integer
function KeyManager:count()
    return #self._maps
end

---@return string
function KeyManager:__tostring()
    return string.format('KeyManager(%d maps)', #self._maps)
end

return KeyManager

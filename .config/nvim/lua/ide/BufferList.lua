-- BufferList: collection of Buffer objects with lifecycle tracking.
-- Automatically syncs with neovim's buffer list via autocommands.
-- Emits events when buffers are opened, closed, or changed.
--
-- Events: 'open', 'close', 'change'

local EventEmitter = require 'ide.EventEmitter'
local Buffer = require 'ide.Buffer'

local BufferList = Class('BufferList')
Class.include(BufferList, EventEmitter)

function BufferList:init()
    self._cache = {} ---@type table<integer, Buffer>
end

--- Get or create a Buffer wrapper for a buffer id.
---@param id integer
---@return Buffer|nil
function BufferList:get(id)
    if not vim.api.nvim_buf_is_valid(id) then
        self._cache[id] = nil
        return nil
    end

    if not self._cache[id] then
        local Buffer = require 'ide.Buffer'
        self._cache[id] = Buffer.get(id)
    end

    return self._cache[id]
end

--- The current buffer.
---@return Buffer
function BufferList:current()
    return assert(self:get(vim.api.nvim_get_current_buf()))
end

--- All listed buffers.
---@return Buffer[]
function BufferList:listed()
    local result = {}
    for _, id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(id) and vim.bo[id].buflisted then
            table.insert(result, self:get(id))
        end
    end
    return result
end

--- All loaded buffers.
---@return Buffer[]
function BufferList:loaded()
    local result = {}
    for _, id in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(id) and vim.api.nvim_buf_is_loaded(id) then
            table.insert(result, self:get(id))
        end
    end
    return result
end

--- All normal (file) buffers.
---@return Buffer[]
function BufferList:normal()
    local result = {}
    for _, buf in ipairs(self:listed()) do
        if buf:is_normal() then
            table.insert(result, buf)
        end
    end
    return result
end

--- Count of listed buffers.
---@return integer
function BufferList:count()
    return #self:listed()
end

--- Find a buffer by file path.
---@param path string
---@return Buffer|nil
function BufferList:find_by_path(path)
    for _, buf in ipairs(self:listed()) do
        if buf:path() == path then
            return buf
        end
    end
    return nil
end

--- Find a buffer by file name (basename).
---@param name string
---@return Buffer|nil
function BufferList:find_by_name(name)
    for _, buf in ipairs(self:listed()) do
        if buf:name() == name then
            return buf
        end
    end
    return nil
end

--- Get the alternate (#) buffer.
---@return Buffer|nil
function BufferList:alternate()
    local alt = vim.fn.bufnr('#')
    if alt > 0 and vim.api.nvim_buf_is_valid(alt) then
        return self:get(alt)
    end
    return nil
end

--- Open a file in the current window.
---@param path string
---@return Buffer|nil
function BufferList:open(path)
    vim.cmd.edit(path)
    return self:current()
end

--- Resolve a target (buffer id, file path, or nil) into a buffer and path.
---@param target integer|string|nil # buffer number, file path, or nil for current
---@return integer, string, boolean # buffer id, canonical path, whether buffer matches path
function BufferList:resolve(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(target) then return 0, '', false end
        local path = vim.api.nvim_buf_get_name(target)
        if not path or path == '' then return target, '', false end
        return target, vim.uv.fs_realpath(path) or path, true
    elseif type(target) == 'string' then
        if target == '' then return vim.api.nvim_get_current_buf(), '', false end
        local path = vim.uv.fs_realpath(target) or target
        for _, buf in ipairs(self:listed()) do
            local bp = buf:path()
            if bp and bp == path then return buf:id(), path, true end
        end
        return vim.api.nvim_get_current_buf(), path, false
    end
    return 0, '', false
end

--- Remove a file from the oldfiles list (v:oldfiles).
---@param file string|nil # file path to forget, or nil to clear all
function BufferList:forget_oldfile(file)
    if not file then
        vim.v.oldfiles = {}
        return
    end
    for i, old in ipairs(vim.v.oldfiles) do
        if old == file then
            table.remove(vim.v.oldfiles, i)
            break
        end
    end
end

--- Switch to a buffer (make it the current buffer in the current window).
---@param buf Buffer|integer
function BufferList:switch_to(buf)
    local id = type(buf) == 'number' and buf or buf:id()
    vim.api.nvim_set_current_buf(id)
end

--- Wire up autocommands to track buffer lifecycle.
--- Called by IDE:init().
function BufferList:_wire_events()
    vim.api.nvim_create_autocmd('BufAdd', {
        callback = function(args)
            local buf = self:get(args.buf)
            if buf then
                self:emit('open', buf)
            end
        end,
    })

    vim.api.nvim_create_autocmd('BufDelete', {
        callback = function(args)
            local buf = self._cache[args.buf]
            if buf then
                self:emit('close', buf)
                self._cache[args.buf] = nil
            end
            Buffer._evict(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
        callback = function(args)
            local buf = self:get(args.buf)
            if buf then
                buf:emit('save')
                self:emit('change', buf)
            end
        end,
    })

    vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
            local buf = self:get(args.buf)
            if buf then
                buf:emit('filetype', buf:filetype())
            end
        end,
    })
end

--- Iterator support.
---@return fun(): Buffer|nil
function BufferList:iter()
    local bufs = self:listed()
    local i = 0
    return function()
        i = i + 1
        return bufs[i]
    end
end

---@return string
function BufferList:__tostring()
    return string.format('BufferList(%d buffers)', self:count())
end

return BufferList

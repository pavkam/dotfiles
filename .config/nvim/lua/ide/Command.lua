-- Command: user command registration abstraction.
-- Wraps nvim_create_user_command with a fluent builder API.
--
-- Usage:
--   Command('Format'):desc('Format buffer'):action(function() buf:format() end):register()
--   Command.register('Reload', function() vim.cmd.source(vim.env.MYVIMRC) end, { desc = 'Reload config' })

local Command = Class('Command')

---@param name string
function Command:init(name)
    assert(type(name) == 'string' and name ~= '', 'command name required')
    self._name = name
    self._opts = { nargs = 0 }
    self._action = function() end
end

---@return string
function Command:name() return self._name end

---@param text string
---@return Command
function Command:desc(text)
    self._opts.desc = text
    return self
end

--- Set the action (callback).
---@param fn fun(args: table)
---@return Command
function Command:action(fn)
    self._action = fn
    return self
end

--- Accept arguments.
---@param nargs string|integer # '0', '1', '*', '?', '+'
---@return Command
function Command:args(nargs)
    self._opts.nargs = nargs
    return self
end

--- Allow bang (!).
---@return Command
function Command:bang()
    self._opts.bang = true
    return self
end

--- Make buffer-local.
---@param bufnr integer
---@return Command
function Command:buffer(bufnr)
    self._bufnr = bufnr
    return self
end

--- Allow range.
---@param range? boolean|string
---@return Command
function Command:range(range)
    self._opts.range = range or true
    return self
end

--- Set completion function.
---@param complete string|function
---@return Command
function Command:complete(complete)
    self._opts.complete = complete
    return self
end

--- Register this command with neovim.
---@return Command
function Command:register()
    if self._bufnr then
        vim.api.nvim_buf_create_user_command(self._bufnr, self._name, self._action, self._opts)
    else
        vim.api.nvim_create_user_command(self._name, self._action, self._opts)
    end
    return self
end

--- Delete this command.
function Command:delete()
    pcall(vim.api.nvim_del_user_command, self._name)
end

---@return string
function Command:__tostring()
    return string.format('Command(%s)', self._name)
end

--- Convenience: create and register in one call.
---@param name string
---@param fn fun(args: table)
---@param opts { desc?: string, nargs?: string|integer, bang?: boolean, range?: boolean|string, complete?: string|function }|nil
---@return Command
function Command.create(name, fn, opts)
    opts = opts or {}
    local cmd = Command(name):action(fn)
    if opts.desc then cmd:desc(opts.desc) end
    if opts.nargs then cmd:args(opts.nargs) end
    if opts.bang then cmd:bang() end
    if opts.range then cmd:range(opts.range) end
    if opts.complete then cmd:complete(opts.complete) end
    return cmd:register()
end

return Command

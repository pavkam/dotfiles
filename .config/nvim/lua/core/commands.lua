--- @class core.commands
local M = {}

---@class (exact) core.commands.RegisterCommandOpts
---@field desc string # the description of the command
---@field nargs integer|'*'|'?'|'+'|nil # the number of arguments the command takes
---@field bang boolean|nil # whether the command takes a bang argument
---@field default_fn string|nil # the default function if none supplied

---@class (exact) vim.CommandCallbackArgs
---@field name string # the name of the command
---@field args string # the arguments passed to the command
---@field fargs string[] # the arguments split by un-escaped white-space
---@field nargs string # the number of arguments
---@field bang boolean # whether the command was executed with a bang
---@field line1 integer # the starting line of the command range
---@field line2 integer # the final line of the command range
---@field range 0|1|2 # the number of items in the command range
---@field count integer # any count supplied
---@field reg string # the optional register, if specified
---@field mods string # the command modifiers, if any
---@field smods table # the command modifiers in a structured format

---@class (exact) core.commands.CommandCallbackArgs: vim.CommandCallbackArgs
---@field split_args string[] # the arguments split by escaped white-space
---@field lines string[] # the lines of the buffer

---@alias core.commands.CommandFunctionCallback fun(args: core.commands.CommandCallbackArgs)
---@alias core.commands.CommandFunctionCallbackSpec { fn: core.commands.CommandFunctionCallback, range: boolean|nil }
---
---@alias core.commands.CommandFunctionSpec core.commands.CommandFunctionCallback
---| core.commands.CommandFunctionCallbackSpec
---@alias core.commands.CommandFunctionArgs core.commands.CommandFunctionSpec
---|core.commands.CommandFunctionSpec[]

--- Parses a string of arguments into a table
---@param args vim.CommandCallbackArgs # the command arguments
---@return string[] # the parsed arguments
local function parse_command_args(args)
    assert(type(args) == 'table')

    local parsed_args = {}
    local in_quote = false
    local current_arg = ''

    for i = 1, #args do
        local char = args.args:sub(i, i)
        if char == '"' then
            in_quote = not in_quote
        elseif char == ' ' and not in_quote then
            if #current_arg > 0 then
                table.insert(parsed_args, current_arg)
                current_arg = ''
            end
        else
            current_arg = current_arg .. char
        end
    end

    if #current_arg > 0 then
        table.insert(parsed_args, current_arg)
    end

    return parsed_args
end

--- Extracts the lines of a buffer described by the command
---@param args vim.CommandCallbackArgs # the command arguments
---@return string[] # the lines of the buffer
local function extract_command_lines(args)
    assert(type(args) == 'table')

    ---@type string[]
    local contents = {}
    if args.range == 2 then
        contents = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, false)
    elseif args.range == 1 then
        contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end

    return contents
end

--- Registers a command that takes a single argument (function)
---@param name string # the name of the command
---@param fn core.commands.CommandFunctionArgs # the function(s) to call when the command is executed
---@param opts core.commands.RegisterCommandOpts|nil # the options to pass to the command
function M.register_command(name, fn, opts)
    assert(type(name) == 'string' and name ~= '')
    assert(type(fn) == 'function' or type(fn) == 'table')

    opts = opts or {}

    if type(fn) == 'function' then
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.CommandCallbackArgs
            function(args)
                fn(vim.tbl_merge(args, { split_args = parse_command_args(args) }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
            }
        )
    elseif type(fn) == 'table' and type(fn.fn) == 'function' then
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.CommandCallbackArgs
            function(args)
                fn.fn(vim.tbl_merge(args, {
                    split_args = parse_command_args(args),
                    lines = fn.range and extract_command_lines(args) or nil,
                }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
                range = fn.range,
            }
        )
    else
        ---@type integer|'*'|'?'|'+'|nil
        local n_args = 1
        if opts.nargs == '?' and opts.default_fn then
            n_args = '?'
        elseif opts.nargs == '*' and not opts.default_fn or opts.nargs == '+' then
            n_args = '+'
        elseif type(opts.nargs) == 'number' then
            if opts.default_fn then
                n_args = opts.nargs
            else
                n_args = n_args + opts.nargs
            end
        end

        local supports_range = #vim.tbl_filter(function(f)
            return type(f) == 'table' and f.range
        end, fn) > 0

        vim.api.nvim_create_user_command(
            name,
            ---@param args core.commands.CommandCallbackArgs
            function(args)
                local func_or_spec = fn[args.fargs[1] or opts.default_fn]
                if not func_or_spec then
                    vim.error(string.format('Unknown function `%s`', args.args))
                    return
                end

                local func = type(func_or_spec) == 'function' and func_or_spec or func_or_spec.fn

                if func then
                    func(vim.tbl_merge(args, {
                        split_args = parse_command_args(args),
                        lines = type(func_or_spec) == 'table' and func_or_spec.range and extract_command_lines(args)
                            or nil,
                    }))
                end
            end,
            {
                desc = opts.desc,
                nargs = n_args,
                bang = opts.bang,
                range = supports_range,
                complete = function(arg_lead)
                    local completions = vim.tbl_keys(fn)
                    local matches = {}

                    for _, value in ipairs(completions) do
                        if value:sub(1, #arg_lead) == arg_lead then
                            table.insert(matches, value)
                        end
                    end

                    return matches
                end,
            }
        )
    end
end

return M

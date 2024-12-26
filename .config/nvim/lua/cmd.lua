---@class cmd
local M = {}

---@class (exact) vim.command_callback_arguments # The arguments passed to a command callback.
---@field name string # the name of the command.
---@field args string # the arguments passed to the command.
---@field fargs string[] # the arguments split by un-escaped white-space.
---@field nargs string # the number of arguments.
---@field bang boolean # whether the command was executed with a bang.
---@field line1 integer # the starting line of the command range.
---@field line2 integer # the final line of the command range.
---@field range 0|1|2 # the number of items in the command range.
---@field count integer # any count supplied.
---@field reg string # the optional register, if specified.
---@field mods string # the command modifiers, if any.
---@field smods table # the command modifiers in a structured format.

---@class (exact) register_command_options # The options to pass to the command.
---@field desc string # the description of the command.
---@field nargs integer|'*'|'?'|'+'|nil # the number of arguments the command takes.
---@field bang boolean|nil # whether the command takes a bang argument.
---@field default_fn string|nil # the default function if none supplied.

---@class (exact) command_callback_arguments: vim.command_callback_arguments
---@field split_args string[] # the arguments split by escaped white-space.
---@field lines string[] # the lines of the buffer.

---@alias command_function_intf # The function interface for a command.
---| fun(args: command_callback_arguments)

---@alias command_function_ext # The function extension for a command.
---| { fn: command_function_intf, range: boolean|nil }

---@alias command_function_spec # The function specification for a command.
---| table<string, command_function_ext | command_function_intf>
---| command_function_ext
---| command_function_intf

--- Parses a string of arguments into a table.
---@param args vim.command_callback_arguments # the command arguments.
---@return string[] # the parsed arguments.
local function parse_command_args(args)
    xassert {
        args = {
            args,
            {
                args = 'string',
            },
        },
    }

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

--- Extracts the lines of a buffer described by the command.
---@param buffer buffer # the buffer to extract the lines from.
---@param args vim.command_callback_arguments # the command arguments.
---@return string[] # the lines of the buffer.
local function extract_command_lines(buffer, args)
    xassert {
        args = {
            args,
            {
                line1 = { 'integer', ['>'] = -1 },
                line2 = { 'integer', ['>'] = -1 },
                range = { 'integer', ['>'] = -1, ['<'] = 3 },
            },
        },
    }

    ---@type string[]
    local contents = {}
    if args.range == 2 then
        contents = buffer.lines(args.line1, args.line2)
    elseif args.range == 1 then
        contents = buffer.lines()
    end

    return contents
end

--- Registers a command that takes a single argument (function).
---@param name string # the name of the command.
---@param spec command_function_spec # the function(s) to call when the command is executed.
---@param opts register_command_options|nil # the options to pass to the command.
function M.register(name, spec, opts)
    ---@type register_command_options
    opts = table.merge(opts, {})

    xassert {
        name = {
            name,
            {
                'string',
                ['>'] = 0,
            },
        },
        spec = {
            spec,
            {
                'callable',
                {
                    fn = 'callable',
                    range = { 'nil', 'boolean' },
                },
                {
                    'table',
                    ['*'] = {
                        'callable',
                        {
                            fn = 'callable',
                            range = { 'nil', 'boolean' },
                        },
                    },
                },
            },
        },
        opts = {
            opts,
            {
                'nil',
                {
                    desc = { 'string', ['>'] = 0 },
                    nargs = { 'nil', 'integer', { 'string', ['*'] = '^%*|?|%+$' } },
                    bang = { 'nil', 'boolean' },
                    default_fn = { 'nil', 'string' },
                },
            },
        },
    }

    local _, ty = xtype(spec)

    if ty == 'callable' then --[[@cast spec command_function_intf]]
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.command_callback_arguments
            function(args)
                spec(table.merge(args, { split_args = parse_command_args(args) }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
            }
        )
    elseif ty == 'table' and spec.fn then --[[@cast spec command_function_ext]]
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.command_callback_arguments
            function(args)
                spec.fn(table.merge(args, {
                    split_args = parse_command_args(args),
                    lines = spec.range and extract_command_lines(ide.buf.current, args) or nil,
                }))
            end,
            {
                desc = opts.desc,
                nargs = opts.nargs,
                bang = opts.bang,
                range = spec.range,
            }
        )
    else --[[@cast spec table<string, command_function_ext | command_function_intf> ]]
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

        local supports_range = false
        for _, item in pairs(spec) do
            _, ty = xtype(item)
            if ty == 'table' and item.range then
                supports_range = true
                break
            end
        end

        vim.api.nvim_create_user_command(
            name,
            ---@param args command_callback_arguments
            function(args)
                local func_or_spec = spec[args.fargs[1] or opts.default_fn]
                if not func_or_spec then
                    ide.tui.error(string.format('Unknown function `%s`', args.args))
                    return
                end

                local func = type(func_or_spec) == 'function' and func_or_spec or func_or_spec.fn

                if func then
                    func(table.merge(args, {
                        split_args = parse_command_args(args),
                        lines = type(func_or_spec) == 'table' and func_or_spec.range and extract_command_lines(
                            ide.buf.current,
                            args
                        ) or nil,
                    }))
                end
            end,
            {
                desc = opts.desc,
                nargs = n_args,
                bang = opts.bang,
                range = supports_range,
                complete = function(arg_lead)
                    local completions = table.keys(spec)
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

return table.freeze(M)

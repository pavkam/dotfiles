math.randomseed(os.time())

---@type string
local uuid_template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

--- Generates a new UUID
---@return string # the generated UUID
function vim.fn.uuid()
    ---@param c string
    local function subs(c)
        local v = (((c == 'x') and math.random(0, 15)) or math.random(8, 11))
        return string.format('%x', v)
    end

    local res = uuid_template:gsub('[xy]', subs)
    return res
end

--- Gets the timezone offset for a given timestamp
---@param timestamp integer # the timestamp to get the offset for
---@return integer # the timezone offset
function vim.fn.timezone_offset(timestamp)
    assert(type(timestamp) == 'number')

    local utc_date = os.date('!*t', timestamp)
    local local_date = os.date('*t', timestamp)

    local_date.isdst = false

    local diff = os.difftime(os.time(local_date --[[@as osdateparam]]), os.time(utc_date --[[@as osdateparam]]))
    local h, m = math.modf(diff / 3600)

    return 100 * h + 60 * m
end

--- Checks if a mode is visual
---@param mode string|nil # the mode to check or the current mode if nil
---@return boolean # true if the mode is visual, false otherwise
function vim.fn.in_visual_mode(mode)
    mode = mode or vim.api.nvim_get_mode().mode

    return mode == 'v' or mode == 'V' or mode == ''
end

--- Gets the selected text from the current buffer in visual mode
---@return string # the selected text
function vim.fn.selected_text()
    if not vim.fn.in_visual_mode() then
        return ''
    end

    local old = vim.fn.getreg 'a'
    vim.cmd [[silent! normal! "aygv]]

    local original_selection = vim.fn.getreg 'a'
    vim.fn.setreg('a', old)

    local res, _ = original_selection:gsub('/', '\\/'):gsub('\n', '\\n')
    return res
end

--- Confirms an operation that requires the buffer to be saved
---@param buffer integer|nil # the buffer to confirm for or the current buffer if 0 or nil
---@param reason string|nil # the reason for the confirmation
---@return boolean # true if the buffer was saved or false if the operation was cancelled
function vim.fn.confirm_saved(buffer, reason)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if vim.bo[buffer].modified then
        local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
        local choice = vim.fn.confirm(
            string.format(message, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ':t'), reason),
            '&Yes\n&No\n&Cancel'
        )

        if choice == 0 or choice == 3 then -- Cancel
            return false
        end

        if choice == 1 then -- Yes
            vim.api.nvim_buf_call(buffer, vim.cmd.write)
        end
    end

    return true
end

--- Forget all a file in the oldfiles list
---@param file string|nil # the file to forget or nil to forget all files
function vim.fn.forget_oldfile(file)
    if not file then
        vim.cmd [[
            let v:oldfiles = []
        ]]
        return
    end

    assert(type(file) == 'string' and file ~= '')

    for i, old_file in ipairs(vim.v.oldfiles) do
        if old_file == file then
            vim.cmd('call remove(v:oldfiles, ' .. (i - 1) .. ')')
            break
        end
    end
end

local undo_command = vim.api.nvim_replace_termcodes('<c-G>u', true, true, true)

--- Creates an undo point if in insert mode.
---@return boolean # true if the undo point was created, false otherwise.
function vim.fn.create_undo_point()
    local is_insert = vim.api.nvim_get_mode().mode == 'i'

    if is_insert then
        vim.api.nvim_feedkeys(undo_command, 'n', false)
    end

    return is_insert
end

---@alias vim.fn.Target string|integer|nil # the target buffer or path or auto-detect

--- Expands a target of any command to a buffer and a path
---@param target vim.fn.Target # the target to expand
---@return integer, string, boolean # the buffer and the path and whether the buffer corresponds to the path
function vim.fn.expand_target(target)
    if type(target) == 'number' or target == nil then
        target = target or vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(target) then
            return 0, '', false
        end

        local path = vim.api.nvim_buf_get_name(target)
        if not path or path == '' then
            return target, '', false
        end

        return target, ide.fs.expand_path(path) or path, true
    elseif type(target) == 'string' then
        ---@cast target string
        if target == '' then
            return vim.api.nvim_get_current_buf(), '', false
        end

        local path = ide.fs.expand_path(target) or target

        for _, buf in ipairs(vim.buf.get_listed_buffers { loaded = false }) do
            local buf_path = vim.api.nvim_buf_get_name(buf)
            if buf_path and buf_path ~= '' and ide.fs.expand_path(buf_path) == path then
                return buf, path, true
            end
        end

        return vim.api.nvim_get_current_buf(), path, false
    else
        error 'Invalid target type'
    end
end

--- Gets the width of the status column
---@param window integer|nil # the window to get the status column width for or the current window if nil
---@return integer|nil # the status column width or nil if the window is invalid
function vim.fn.status_column_width(window)
    window = window or vim.api.nvim_get_current_win()
    local info = vim.fn.getwininfo(window)
    if vim.api.nvim_win_is_valid(window) and info[1] then
        return info[1].textoff
    end

    return nil
end

--- Toggles a fold at a given line
---@param line integer|nil # the line to toggle the fold for or the current line if nil
---@window integer|nil # the window to use for the operation or the current window if nil
---@return boolean|nil # true if the fold was opened, false if it was closed, nil if the line is not foldable
function vim.fn.toggle_fold(line, window)
    window = window or vim.api.nvim_get_current_win()
    line = line or vim.api.nvim_win_get_position(window)[1]

    assert(type(line) == 'number' and line >= 0)
    assert(type(window) == 'number')

    return vim.api.nvim_win_call(window, function()
        if vim.fn.foldclosed(line) == line then
            vim.cmd(string.format('%dfoldopen', line))
            return true
        elseif vim.fn.foldlevel(line) > 0 then
            vim.cmd(string.format('%dfoldclose', line))
            return false
        end

        return nil
    end)
end

--- Gets the state of a fold marker at a given line (where fold starts)
---@param line integer|nil # the line to get the fold state for or the current line if nil
---@param window integer|nil # the window to use for the operation or the current window if nil
---@return boolean|nil # true if the fold marker should show "closed", false if it is "open", nil if no marker
function vim.fn.fold_marker(line, window)
    window = window or vim.api.nvim_get_current_win()
    line = line or vim.api.nvim_win_get_position(window)[1]

    assert(type(line) == 'number' and line >= 0)
    assert(type(window) == 'number')

    return vim.api.nvim_win_call(window, function()
        if vim.fn.foldclosed(line) >= 0 then
            return true
        elseif tostring(vim.treesitter.foldexpr(line)):sub(1, 1) == '>' then
            return false
        end

        return nil
    end)
end

--- Checks if a window is in diff mode.
---@param window integer|nil # the window to check or the current window if nil
---@return boolean # true if the window is in diff mode, false otherwise
function vim.fn.win_in_diff_mode(window)
    window = window or vim.api.nvim_get_current_win()
    assert(type(window) == 'number')

    return vim.api.nvim_get_option_value('diff', { win = window })
end

---@class (exact) vim.fn.RegisterCommandOpts # The options to pass to the command.
---@field desc string # the description of the command.
---@field nargs integer|'*'|'?'|'+'|nil # the number of arguments the command takes.
---@field bang boolean|nil # whether the command takes a bang argument.
---@field default_fn string|nil # the default function if none supplied.

---@class (exact) vim.api.CommandCallbackArgs # The arguments passed to a command callback.
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

---@class (exact) vim.fn.CommandCallbackArgs: vim.api.CommandCallbackArgs
---@field split_args string[] # the arguments split by escaped white-space.
---@field lines string[] # the lines of the buffer.

---@alias vim.fn.CommandFunctionSpec
---| fun(args: vim.fn.CommandCallbackArgs)
---| { fn: fun(args: vim.fn.CommandCallbackArgs), range: boolean|nil }

---@alias vim.fn.CommandFunctionArgs
---| vim.fn.CommandFunctionSpec
---| vim.fn.CommandFunctionSpec[]

--- Parses a string of arguments into a table.
---@param args vim.api.CommandCallbackArgs # the command arguments.
---@return string[] # the parsed arguments.
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

--- Extracts the lines of a buffer described by the command.
---@param args vim.api.CommandCallbackArgs # the command arguments.
---@return string[] # the lines of the buffer.
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

--- Registers a command that takes a single argument (function).
---@param name string # the name of the command.
---@param fn vim.fn.CommandFunctionArgs # the function(s) to call when the command is executed.
---@param opts vim.fn.RegisterCommandOpts|nil # the options to pass to the command.
function vim.fn.user_command(name, fn, opts)
    assert(type(name) == 'string' and name ~= '')
    assert(type(fn) == 'function' or type(fn) == 'table')

    opts = opts or {}

    if type(fn) == 'function' then
        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.api.CommandCallbackArgs
            function(args)
                fn(table.merge(args, { split_args = parse_command_args(args) }))
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
            ---@param args vim.api.CommandCallbackArgs
            function(args)
                fn.fn(table.merge(args, {
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

        local supports_range = vim.iter(fn):any(
            ---@param f vim.fn.CommandFunctionSpec
            function(f)
                if type(f) == 'table' and f.range then
                    return true
                end

                return false
            end
        )

        vim.api.nvim_create_user_command(
            name,
            ---@param args vim.fn.CommandCallbackArgs
            function(args)
                local func_or_spec = fn[args.fargs[1] or opts.default_fn]
                if not func_or_spec then
                    ide.tui.error(string.format('Unknown function `%s`', args.args))
                    return
                end

                local func = type(func_or_spec) == 'function' and func_or_spec or func_or_spec.fn

                if func then
                    func(table.merge(args, {
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

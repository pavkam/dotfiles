local utils = require 'utils'
local shell = require 'utils.shell'
local health = require 'utils.health'

--- Parses a string of arguments into a table
---@param args string # the string of arguments to parse
---@return string[] # the parsed arguments
local function parse_args(args)
    local parsed_args = {}
    local in_quote = false
    local current_arg = ''

    for i = 1, #args do
        local char = args:sub(i, i)
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

-- Show buffer information
vim.api.nvim_create_user_command('Buffer', function()
    health.show_for_buffer()
end, { desc = 'Show buffer information', nargs = 0 })

vim.api.nvim_create_user_command('Run', function(args)
    local cmd_line = parse_args(args.args)
    if #cmd_line == 0 then
        error 'No command specified'
    end

    local cmd_line_desc = table.concat(cmd_line, ' ')
    local cmd = table.remove(cmd_line, 1)

    shell.async_cmd(cmd, cmd_line, function(output)
        if not args.bang then
            if #output > 0 then
                local message = table.concat(output, '\n')
                message = message:gsub('```', '\\`\\`\\`')

                utils.info(string.format('Command "%s" finished:\n\n```sh\n%s\n```', cmd_line_desc, message))
            else
                utils.info(string.format('Command "%s" finished', cmd_line_desc))
            end
        end
    end)
end, { desc = 'Run a shell command', bang = true, nargs = '+' })

-- File manipulation
utils.on_user_event('NormalFile', function(_, evt)
    -- TODO: use the new shell module to invoke commands
    vim.api.nvim_buf_create_user_command(evt.buf, 'Rename', function(args)
        local old_path = vim.fn.expand '%:p'
        local old_file_name = vim.fn.expand '%:t'

        local function rename(new_name)
            local directory = vim.fn.expand '%:h'
            local new_path = utils.join_paths(directory, new_name)
            ---@cast new_path string

            if not utils.file_exists(new_path) then
                vim.api.nvim_buf_set_name(evt.buf, new_name)
                return
            end

            shell.async_cmd('mv', { old_path, new_path }, function()
                require('mini.bufremove').delete(0, true)

                vim.api.nvim_command(string.format('e %s', new_path))

                require('utils.lsp').notify_file_renamed(old_path, new_path)
            end)
        end

        if args.args ~= '' then
            rename(args.args)
            return
        end

        vim.ui.input({ prompt = 'New name: ', default = old_file_name }, function(new_name)
            if new_name == nil or new_name == '' or new_name == old_file_name then
                return
            end

            rename(new_name)
        end)
    end, { desc = 'Rename current file', nargs = '?' })

    vim.api.nvim_buf_create_user_command(evt.buf, 'Delete', function(args)
        local path = vim.fn.expand '%:p'
        local name = vim.fn.expand '%:t'

        if not utils.file_exists(path) then
            require('mini.bufremove').delete(0, true)
            return
        end

        local function delete()
            shell.async_cmd('rm', { path }, function()
                require('mini.bufremove').delete(0, true)
            end, { no_checktime = true })
        end

        if not args.bang then
            local message = string.format('Are you sure you want to delete %s?', name)
            local choice = vim.fn.confirm(message, '&Yes\n&No')
            if choice ~= 1 then -- Yes
                return
            end
        end

        delete()
    end, { desc = 'Delete current file', nargs = 0, bang = true })
end)

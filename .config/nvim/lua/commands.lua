local utils = require 'utils'

-- Show buffer information
vim.api.nvim_create_user_command('Buffer', function()
    local health = require 'utils.health'
    health.show_for_buffer()
end, { desc = 'Show buffer information', nargs = 0 })

-- File manipulation
utils.on_user_event('NormalFile', function(_, evt)
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

            vim.api.nvim_command(string.format('!mv "%%" "%s"', new_path))

            if utils.file_exists(new_path) then
                require('mini.bufremove').delete(0, true)

                vim.api.nvim_command(string.format('e %s', new_path))

                require('utils.lsp').notify_file_renamed(old_path, new_path)
            else
                utils.error(string.format('Failed to rename file "%s" to "%s"!', old_path, new_path))
            end
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
            vim.api.nvim_command(string.format('!rm "%%"', path))
            if not utils.file_exists(path) then
                require('mini.bufremove').delete(0, true)
            else
                utils.error(string.format('Failed to delete file "%s"!', name))
            end
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

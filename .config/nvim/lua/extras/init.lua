local utils = require 'core.utils'

require 'extras.health'
require 'extras.notes'

-- File manipulation (delete, rename)
utils.on_user_event('NormalFile', function(_, evt)
    local function delete_buffer(buffer)
        if package.loaded['mini.bufremove'] then
            require('mini.bufremove').delete(buffer, true)
        else
            vim.api.nvim_command(string.format('bdelete %s', buffer))
        end
    end

    vim.api.nvim_buf_create_user_command(evt.buf, 'Rename', function(args)
        local old_path = vim.api.nvim_buf_get_name(evt.buf)
        local old_file_name = vim.fn.fnamemodify(old_path, ':t')
        local directory = vim.fn.fnamemodify(old_path, ':h')

        local function rename(new_name)
            local new_path = utils.join_paths(directory, new_name)
            ---@cast new_path string

            if not utils.file_exists(old_path) then
                vim.api.nvim_buf_set_name(evt.buf, new_name)
                return
            end

            local ok, _, msg = vim.loop.fs_rename(old_path, new_path)
            if not ok then
                utils.error(string.format('Failed to rename file: **%s**', msg))
                return
            end

            delete_buffer(evt.buf)

            vim.api.nvim_command(string.format('e %s', new_path))
            require('project.lsp').notify_file_renamed(old_path, new_path)
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
        local path = vim.api.nvim_buf_get_name(evt.buf)
        local name = vim.fn.fnamemodify(path, ':t')

        if not utils.file_exists(path) then
            delete_buffer(evt.buf)
            return
        end

        if not args.bang then
            local message = string.format('Are you sure you want to delete %s?', name)
            local choice = vim.fn.confirm(message, '&Yes\n&No')
            if choice ~= 1 then -- Yes
                return
            end
        end

        local ok, _, msg = vim.loop.fs_unlink(path)
        if not ok then
            utils.error(string.format('Failed to delete file: **%s**', msg))
            return
        end

        delete_buffer(evt.buf)
    end, { desc = 'Delete current file', nargs = 0, bang = true })
end)

-- Some custom mappings for file types
if vim.fn.executable 'jq' then
    utils.attach_keymaps('json', function(set)
        set('n', '=', ':%Apply jq .<cr>', { desc = 'Pretty-format JSON' })
    end)
end

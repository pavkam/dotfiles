local utils = require 'core.utils'
local toggles = require 'core.toggles'
local shell = require 'core.shell'
local forget = require 'core.forget'

utils.on_event('BufDelete', function(evt)
    if utils.is_special_buffer(evt.buf) then
        return
    end

    local file = vim.api.nvim_buf_get_name(evt.buf)
    if not file or file == '' or utils.file_exists(file) then
        return
    end

    forget.file(file)
end)

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

vim.api.nvim_create_user_command('Run', function(args)
    local cmd_line = parse_args(args.args)
    if #cmd_line == 0 then
        error 'No command specified'
    end

    local cmd_line_desc = table.concat(cmd_line, ' ')
    local cmd = table.remove(cmd_line, 1)

    shell.async_cmd(cmd, cmd_line, nil, function(output)
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

vim.api.nvim_create_user_command('Apply', function(args)
    local cmd_line = parse_args(args.args)
    if #cmd_line == 0 then
        error 'No command specified'
    end

    local cmd = table.remove(cmd_line, 1)

    -- extract the contents
    ---@type integer|nil
    local start_line = args.line1
    ---@type integer|nil
    local end_line = args.line2
    ---@type string[]
    local contents

    if start_line and end_line then
        contents = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    else
        contents = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    end

    shell.async_cmd(cmd, cmd_line, contents, function(output)
        if start_line and end_line then
            vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, output)
        else
            vim.api.nvim_buf_set_lines(0, 0, -1, false, output)
        end
    end)
end, { desc = 'Apply a shell command', nargs = '+', range = '%' })

-- diagnostics
local function jump_to_diagnostic(next_or_prev, severity)
    local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev

    severity = severity and vim.diagnostic.severity[severity] or nil

    return function()
        go { severity = severity }
    end
end

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
            require('languages').notify_file_renamed(old_path, new_path)
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

-- Add a command to run lazygit
if vim.fn.executable 'lazygit' == 1 then
    vim.api.nvim_create_user_command('Lazygit', function()
        shell.floating 'lazygit'
    end, { desc = 'Run Lazygit', nargs = 0 })

    vim.keymap.set('n', '<leader>gg', function()
        vim.cmd 'Lazygit'
    end, { desc = 'Lazygit' })
end

vim.keymap.set('n', ']m', jump_to_diagnostic(true), { desc = 'Next Diagnostic' })
vim.keymap.set('n', '[m', jump_to_diagnostic(false), { desc = 'Previous Diagnostic' })
vim.keymap.set('n', ']e', jump_to_diagnostic(true, 'ERROR'), { desc = 'Next Error' })
vim.keymap.set('n', '[e', jump_to_diagnostic(false, 'ERROR'), { desc = 'Previous Error' })
vim.keymap.set('n', ']w', jump_to_diagnostic(true, 'WARN'), { desc = 'Next Warning' })
vim.keymap.set('n', '[w', jump_to_diagnostic(false, 'WARN'), { desc = 'Previous Warning' })

vim.keymap.set('n', '<leader>uM', function()
    toggles.toggle_diagnostics()
end, { desc = 'Toggle global diagnostics' })

vim.keymap.set('n', '<leader>um', function()
    toggles.toggle_diagnostics { buffer = vim.api.nvim_get_current_buf() }
end, { desc = 'Toggle buffer diagnostics' })

-- Treesitter
vim.keymap.set('n', '<leader>ut', function()
    toggles.toggle_treesitter { buffer = vim.api.nvim_get_current_buf() }
end, { desc = 'Toggle buffer treesitter' })

-- show hidden
if feature_level(1) then
    vim.keymap.set('n', '<leader>uh', function()
        toggles.toggle_ignore_hidden_files()
    end, { desc = 'Toggle show hidden' })
end

-- Command mode remaps to make my life easier using the keyboard
vim.keymap.set('c', '<Down>', function()
    if vim.fn.wildmenumode() then
        return '<C-n>'
    else
        return '<Down>'
    end
end, { expr = true })

vim.keymap.set('c', '<Up>', function()
    if vim.fn.wildmenumode() then
        return '<C-p>'
    else
        return '<Up>'
    end
end, { expr = true })

vim.keymap.set('c', '<Left>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Left>'
    else
        return '<Left>'
    end
end, { expr = true })

vim.keymap.set('c', '<Right>', function()
    if vim.fn.wildmenumode() then
        return '<Space><BS><Right>'
    else
        return '<Right>'
    end
end, { expr = true })

-- Add "q" to special windows
utils.attach_keymaps(utils.special_file_types, function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end)

utils.attach_keymaps('help', function(set)
    set('n', 'q', '<cmd>close<cr>', { silent = true })
    set('n', '<Esc>', '<cmd>close<cr>', { silent = true })
end, true)

-- Some custom mappings for file types
if vim.fn.executable 'jq' then
    utils.attach_keymaps('json', function(set)
        set('n', '<leader>sJ', ':%Apply jq .<cr>', { desc = 'Pretty-format JSON' })
    end)
end

-- Specials using "Command/Super" key (when available!)
vim.keymap.set('n', '<M-]>', '<C-i>', { desc = 'Next location' })
vim.keymap.set('n', '<M-[>', '<C-o>', { desc = 'Previous location' })
vim.keymap.set('n', '<M-s>', '<cmd>w<cr>', { desc = 'Save buffer' })
vim.keymap.set('n', '<M-x>', 'dd', { desc = 'Delete line' })
vim.keymap.set('x', '<M-x>', 'd', { desc = 'Delete selection' })

-- misspellings
vim.cmd.cnoreabbrev('qw', 'wq')
vim.cmd.cnoreabbrev('Wq', 'wq')
vim.cmd.cnoreabbrev('WQ', 'wq')
vim.cmd.cnoreabbrev('Qa', 'qa')
vim.cmd.cnoreabbrev('Bd', 'bd')
vim.cmd.cnoreabbrev('bD', 'bd')

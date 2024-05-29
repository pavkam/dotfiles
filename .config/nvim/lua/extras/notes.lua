local utils = require 'core.utils'
local syntax = require 'editor.syntax'

--- Get the notes root directory
---@param global boolean|nil: If true, return the global notes root
---@return string: The notes root directory
local function get_notes_root(global)
    local root
    if global then
        root = os.getenv 'WORK_NOTES_ROOT'
        if root == nil then
            error 'WORK_NOTES_ROOT is not set'
        end
    else
        ---@type string
        root = utils.join_paths(require('project').root(nil, false), '.notes')
    end

    return root
end

--- Greps the notes directory
---@param global boolean|nil: If true, grep the global notes directory
local function grep(global)
    local telescope = require 'telescope.builtin'
    local root = get_notes_root(global)
    if vim.fn.isdirectory(root) == 0 then
        utils.info 'No notes saved'
        return
    end

    telescope.live_grep {
        additional_args = function(args)
            return vim.list_extend(args, { '--hidden', '--no-ignore' })
        end,
        cwd = root,
    }
end

--- Finds files in the notes directory
---@param global boolean|nil: If true, find files in the global notes directory
local function find(global)
    local telescope = require 'telescope.builtin'
    local root = get_notes_root(global)
    if vim.fn.isdirectory(root) == 0 then
        utils.info 'No notes saved'
        return
    end

    telescope.find_files {
        additional_args = function(args)
            return vim.list_extend(args, { '--hidden', '--no-ignore' })
        end,

        cwd = root,
    }
end

--- Edits a new or existing note
---@param global boolean|nil: If true, edit a new note in the global notes directory
local function edit(global)
    local file_name = utils.join_paths(get_notes_root(global), os.date '%Y-%m-%d' .. '.md')
    vim.api.nvim_command('edit ' .. file_name)
end

--- Edits a new or existing note
---@param title string|nil: The title of the note
---@param lines string[]: The lines to append to the note
---@param global boolean|nil: If true, edit a new note in the global notes directory
local function append(title, lines, global)
    local ft = vim.bo.filetype
    edit(global)

    if #lines > 0 then
        table.insert(lines, 1, string.format('```%s', ft))
        table.insert(lines, '```')
    end

    if title then
        table.insert(lines, 1, string.format('### %s', title))
    end

    vim.api.nvim_put(lines, 'l', true, true)
end

-- TODO: migrate to new API
vim.api.nvim_create_user_command('Note', function(args)
    if args.args == 'list' then
        find(args.bang)
        return
    end

    if args.args == 'grep' then
        grep(args.bang)
        return
    end

    if args.args == 'open' then
        edit(args.bang)
        return
    end

    if args.args == 'append' or args.args == '' then
        local lines = syntax.lines(nil, args.line1, args.line2)

        if #lines == 0 then
            utils.error 'No lines selected'
        else
            local title = string.format('Lines %d-%d from %s:', args.line1, args.line2, vim.fn.expand '%')
            append(title, lines, args.bang)
        end

        return
    end

    utils.error 'Invalid argument'
end, {
    desc = 'Manages notes',
    complete = function(arg_lead)
        local completions = { 'list', 'grep', 'open', 'append' }
        local matches = {}

        for _, value in ipairs(completions) do
            if value:sub(1, #arg_lead) == arg_lead then
                table.insert(matches, value)
            end
        end

        return matches
    end,
    nargs = '?',
    range = true,
    bang = true,
})

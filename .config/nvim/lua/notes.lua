local project = require 'project'

-- TODO: this is broken for :Note

--- Get the notes root directory
---@param global boolean|nil: If true, return the global notes root
---@return string: The notes root directory
local function get_notes_root(global)
    ---@type string|nil
    local root

    if global then
        root = vim.env.WORK_NOTES_ROOT or vim.fn.stdpath 'data' --[[@as string|nil]]
    else
        root = project.nvim_settings_path()
        root = root and vim.fs.joinpath(root, 'notes')
    end

    return assert(root)
end

--- Greps the notes directory
---@param global boolean|nil: If true, grep the global notes directory
local function grep(global)
    local telescope = require 'telescope.builtin'
    local root = get_notes_root(global)
    if not ide.fs.directory_exists(root) then
        ide.tui.info 'No notes saved'
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
    if not ide.fs.directory_exists(root) then
        ide.tui.info 'No notes saved'
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
    local file_name = vim.fs.joinpath(get_notes_root(global), os.date '%Y-%m-%d' .. '.md')
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

ide.command.register('Note', {
    open = function(args)
        edit(args.bang)
    end,
    append = {
        fn = function(args)
            if not args.lines or #args.lines == 0 then
                ide.tui.error 'No lines selected'
            else
                local title
                if args.range == 2 then
                    title = string.format('Lines %d-%d from %s:', args.line1, args.line2, vim.fn.expand '%')
                elseif args.range == 1 then
                    title = string.format('Line %d from %s:', args.line1, vim.fn.expand '%')
                end

                append(title, args.lines, args.bang)
            end
        end,
        range = true,
    },
}, {
    default_fn = 'append',
    desc = 'Open/Append to note',
    nargs = '?',
    bang = true,
})

ide.command.register('Notes', {
    list = function(args)
        find(args.bang)
    end,
    grep = function(args)
        grep(args.bang)
    end,
}, {
    default_fn = 'grep',
    desc = 'Manages notes',
    nargs = 1,
    bang = true,
})

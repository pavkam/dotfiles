local utils = require 'core.utils'
local icons = require 'ui.icons'

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
    vim.ui.input({ prompt = 'Note name: ', default = os.date '%Y-%m-%d' }, function(name)
        if name == nil or name == '' then
            return
        end

        local file_name = utils.join_paths(get_notes_root(global), name .. '.md')
        vim.api.nvim_command('edit ' .. file_name)
    end)
end

if feature_level(2) then
    vim.keymap.set('n', '<leader>n', function()
        require('ui.select').command {
            {
                name = 'Show global notes',
                hl = 'SpecialMenuItem',
                desc = 'global notes',
                command = function()
                    find(true)
                end,
            },
            {
                name = 'Grep global notes',
                hl = 'SpecialMenuItem',
                desc = 'global notes',
                command = function()
                    grep(true)
                end,
            },
            {
                name = 'Open global note',
                hl = 'SpecialMenuItem',
                desc = 'global notes',
                command = function()
                    edit(true)
                end,
            },
            {
                name = 'Show project notes',
                desc = 'project-specific notes',
                command = function()
                    find(false)
                end,
            },
            {
                name = 'Grep project notes',
                desc = 'project-specific notes',
                command = function()
                    grep(false)
                end,
            },
            {
                name = 'Open project note',
                desc = 'project-specific notes',
                command = function()
                    edit(false)
                end,
            },
        }
    end, { desc = icons.UI.Notes .. ' Notes' })
end

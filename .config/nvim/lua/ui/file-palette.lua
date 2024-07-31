local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local utils = require 'core.utils'
local keys = require 'core.keys'
local icons = require 'ui.icons'
local project = require 'project'

-- URGENT: This is shit -- opening crappy empty file
-- E5108: Error executing lua: vim/_editor.lua:0: nvim_exec2(): Vim(edit):E32: No file name
-- stack traceback:
-- 	[C]: in function 'nvim_exec2'
-- 	vim/_editor.lua: in function 'cmd'
-- 	/Users/alex/.config/nvim/lua/ui/file-palette.lua:326: in function 'run_replace_or_original'
-- 	...re/nvim/lazy/telescope.nvim/lua/telescope/actions/mt.lua:65: in function 'key_func'
-- 	...hare/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua:293: in function <...hare/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua:292>
--

---@class ui.file_palette.Options
---@field buffer number|nil # The buffer number, 0 or nil for the current buffer
---@field column_separator string|nil # The column separator

---@class ui.file_palette.File
---@field file string # The file name
---@field type 'buffer' | 'old-file' | 'jump-list' | string # The type of file
---@field line number # The line number

---@type table<string, boolean>
local session_open_files = {}

utils.on_event('BufRead', function(evt)
    local path = utils.is_regular_buffer(evt.buf) and vim.api.nvim_buf_get_name(evt.buf)
    if not path or not utils.file_exists(path) then
        return
    end

    session_open_files[path] = true
end)

--- Get all listed buffers
---@return ui.file_palette.File[] # List of files
local function get_listed_buffers()
    return vim.iter(utils.get_listed_buffers { loaded = false, listed = false })
        :map(function(buffer)
            return {
                file = vim.api.nvim_buf_get_name(buffer),
                type = 'buffer',
                line = vim.api.nvim_buf_get_mark(buffer, [["]])[1],
            }
        end)
        :totable()
end

--- Get all seen files
---@return ui.file_palette.File[] # List of files
local function get_opened_files()
    return vim.iter(vim.tbl_keys(session_open_files))
        :map(
            ---@param file string
            function(file)
                return {
                    file = file,
                    type = 'old-file',
                    line = 1,
                }
            end
        )
        :totable()
end

--- Get all global marked files
---@return ui.file_palette.File[] # List of files
local function get_global_marked_files()
    -- Get the global marks and sort them so that numeric marks come first
    ---@type ui.marks.Mark[]
    local marks = vim.fn.getmarklist()
    table.sort(
        marks,
        ---@param a ui.marks.Mark
        ---@param b ui.marks.Mark
        function(a, b)
            return a.mark > b.mark
        end
    )

    return vim.iter(marks)
        :filter(
            ---@param mark ui.marks.Mark
            function(mark)
                return utils.file_exists(mark.file) and mark.mark:match [[^'[A-Z]$]]
            end
        )
        :map(
            ---@param mark ui.marks.Mark
            function(mark)
                return {
                    file = mark.file,
                    type = mark.mark,
                    line = mark.pos[2],
                }
            end
        )
        :totable()
end

--- Get all local file marks
---@return ui.file_palette.File[] # List of files
local function get_marked_buffer(buffer)
    if not utils.is_regular_buffer(buffer) then
        return {}
    end

    -- Get the global marks and sort them so that numeric marks come first
    ---@type ui.marks.Mark[]
    local marks = vim.fn.getmarklist(buffer)
    table.sort(
        marks,
        ---@param a ui.marks.Mark
        ---@param b ui.marks.Mark
        function(a, b)
            return a.mark < b.mark
        end
    )

    local buffer_name = vim.api.nvim_buf_get_name(buffer)

    return vim.iter(marks)
        :filter(
            ---@param mark ui.marks.Mark
            function(mark)
                return mark.mark:match [[^'[a-z]$]]
            end
        )
        :map(
            ---@param mark ui.marks.Mark
            function(mark)
                return {
                    file = buffer_name,
                    type = mark.mark,
                    line = mark.pos[2],
                }
            end
        )
        :totable()
end

--- Get all jump-list files
---@return ui.file_palette.File[] # List of files
local function get_jump_list_files()
    local jumplist = vim.fn.getjumplist()[1]

    ---@type ui.file_palette.File[]
    local results = {}

    -- Get the jump-list and sort it so that the most recent files come first
    for i = #jumplist, 1, -1 do
        local buffer = jumplist[i].bufnr
        local path = utils.is_regular_buffer(buffer) and vim.api.nvim_buf_get_name(buffer)

        if path and utils.file_exists(path) then
            table.insert(results, {
                file = path,
                type = 'jump-list',
                line = jumplist[i].lnum,
            })
        end
    end

    return results
end

--- Get all old files
---@return ui.file_palette.File[] # List of files
local function get_old_files()
    return vim.iter(vim.v.oldfiles)
        :filter(
            ---@param file string
            function(file)
                return utils.file_exists(file)
            end
        )
        :map(
            ---@param file string
            function(file)
                return {
                    file = file,
                    type = 'old-file',
                    line = 1,
                }
            end
        )
        :totable()
end

---@class ui.file_palette.Entry
---@field short_name string # The short name
---@field filename string # The file name
---@field lnum number # The line number
---@field type string # The type of file entry

--- Get all operating files
---@param opts ui.file_palette.Options # The options
---@return ui.file_palette.Entry[] # List of items
local function get_items(opts)
    assert(type(opts) == 'table')

    ---@type ui.file_palette.File[]
    local all = get_listed_buffers()
    vim.list_extend(all, get_marked_buffer(opts.buffer))
    vim.list_extend(all, get_global_marked_files())
    vim.list_extend(all, get_jump_list_files())
    vim.list_extend(all, get_old_files())
    vim.list_extend(all, get_opened_files())

    ---@type table<string, boolean>
    local seen_linewise = {}
    ---@type table<string, boolean>
    local seen_filewise = {}

    return vim.iter(all)
        :map(
            ---@param file ui.file_palette.File
            function(file)
                return {
                    file = vim.fn.expand(file.file),
                    line = file.line,
                    type = file.type,
                }
            end
        )
        :filter(
            ---@param file ui.file_palette.File
            function(file)
                local meta = file.file .. ':' .. file.line
                if seen_linewise[meta] or (file.line <= 1 and seen_filewise[file.file]) then
                    return false
                end

                seen_linewise[meta] = true
                seen_filewise[file.file] = true
                return true
            end
        )
        :map(
            ---@param file ui.file_palette.File
            function(file)
                return {
                    short_name = project.format_relative(file.file),
                    filename = file.file,
                    lnum = file.line,
                    type = file.type,
                }
            end
        )
        :totable()
end

--- Gets the displayer
---@param type_col_width number # The width of the type column
---@param opts ui.file_palette.Options
local function get_displayer(type_col_width, opts)
    return entry_display.create {
        separator = opts.column_separator,
        items = {
            { width = type_col_width },
            { width = 2 },
            { remaining = true },
        },
    }
end

--- Get the entry maker
---@param displayer function # The displayer
local function get_entry_maker(displayer)
    ---@param entry ui.file_palette.Entry
    local make_display = function(entry)
        local icon, hl = icons.get_file_icon(entry.filename)

        return displayer {
            { entry.type, 'TelescopeResultsComment' },
            { icon, hl },
            { entry.short_name, 'CommandPaletteMarkedFile' },
        }
    end

    ---@param entry ui.file_palette.Entry
    return function(entry)
        return utils.tbl_merge(entry, {
            ordinal = entry.filename,
            display = make_display,
        })
    end
end

---@class ui.file_palette
local M = {}

--- Open the command palette (internal)
---@param opts ui.file_palette.Options # The options
local function show_file_palette(opts)
    assert(type(opts) == 'table')

    local items = get_items(opts)

    local type_col_width = 0
    for _, item in ipairs(items) do
        type_col_width = math.max(type_col_width, #item.type)
    end

    local displayer = get_displayer(type_col_width + 1, opts)
    local entry_maker = get_entry_maker(displayer)

    pickers
        .new(opts, {
            prompt_title = 'Recent Files',
            finder = finders.new_table {
                results = items,
                entry_maker = entry_maker,
            },
            sorter = conf.generic_sorter(opts),
            previewer = conf.grep_previewer(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    ---@cast selection ui.file_palette.Entry|nil
                    if selection == nil then
                        utils.warn 'Nothing has been selected'
                        return
                    end

                    actions.close(prompt_bufnr)

                    vim.cmd('edit +' .. selection.lnum .. ' ' .. selection.filename)
                end)

                return true
            end,
        })
        :find()
end

--- Open the command palette
---@param opts ui.file_palette.Options|nil # The options
function M.show_file_palette(opts)
    opts = opts or {}

    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    opts.column_separator = opts.column_separator or (' ' .. icons.Symbols.ColumnSeparator .. ' ')

    show_file_palette(opts)
end

utils.register_command('Files', function()
    M.show_file_palette()
end, { desc = 'Show file palette' })

keys.map('n', '<F3>', '<cmd>Files<cr>', { desc = 'Show file palette' })
keys.map('n', '<leader>b', '<cmd>Files<cr>', { desc = 'Show file palette' })

return M

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local entry_display = require 'telescope.pickers.entry_display'
local events = require 'events'
local keys = require 'keys'
local icons = require 'icons'
local project = require 'project'

---@class ui.file_palette.Options
---@field buffer number|nil # The buffer number, 0 or nil for the current buffer
---@field column_separator string|nil # The column separator

---@class ui.file_palette.File
---@field file string # The file name
---@field type 'buffer' | 'old-file' | 'jump-list' | string # The type of file
---@field line number # The line number

---@type table<string, boolean>
local session_open_files = {}

events.on_event('BufRead', function(evt)
    local path = vim.buf.is_regular(evt.buf) and vim.api.nvim_buf_get_name(evt.buf)
    if not path or not ide.fs.file_exists(path) then
        return
    end

    session_open_files[path] = true
end)

--- Get all listed buffers
---@return ui.file_palette.File[] # List of files
local function get_listed_buffers()
    local all = vim.buf.get_listed_buffers()
    vim.list_extend(all, vim.buf.get_listed_buffers { loaded = false, listed = false })

    all = table.list_uniq(all)
    table.sort(
        all,
        ---@param a integer
        ---@param b integer
        function(a, b)
            return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
        end
    )

    return vim.iter(all)
        :map(function(buffer)
            local name = vim.api.nvim_buf_get_name(buffer)
            return {
                file = name and name ~= '' and name or '[No Name]',
                type = 'buffer',
                line = ide.buf[buffer].cursor[1],
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
                return ide.fs.file_exists(mark.file) and mark.mark:match [[^'[A-Z]$]]
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
    if not vim.buf.is_regular(buffer) then
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
        local path = vim.buf.is_regular(buffer) and vim.api.nvim_buf_get_name(buffer)

        if path and ide.fs.file_exists(path) then
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
                return ide.fs.file_exists(file)
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

-- TODO: add git modified files
-- LOW: all project files as well?

--- Get all operating files
---@param opts ui.file_palette.Options # The options
---@return ui.file_palette.Entry[] # List of items
local function get_items(opts)
    assert(type(opts) == 'table')

    ---@type ui.file_palette.File[]
    local all = get_listed_buffers()
    vim.list_extend(all, get_opened_files())
    vim.list_extend(all, get_jump_list_files())
    vim.list_extend(all, get_old_files())
    vim.list_extend(all, get_marked_buffer(opts.buffer))
    vim.list_extend(all, get_global_marked_files())

    local mapped = vim.iter(all)
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

    return table.list_uniq(
        mapped,
        ---@param file ui.file_palette.Entry
        function(file)
            return file.filename
        end
    )
end

--- Gets the displayer
---@param opts ui.file_palette.Options
local function get_displayer(opts)
    return entry_display.create {
        separator = opts.column_separator,
        items = {
            { width = 3 },
            { remaining = true },
        },
    }
end

ide.theme.register_highlight_groups {
    FilePaletteOpenFile = '@lsp.type.variable',
    FilePaletteJumpedFile = '@lsp.type.decorator',
    FilePaletteOldFile = '@lsp.type.number',
    FilePaletteMarkedFile = '@keyword',
}

local hl_map = {
    ['old-file'] = 'FilePaletteOldFile',
    ['jump-list'] = 'FilePaletteJumpedFile',
    ['buffer'] = 'FilePaletteOpenFile',
    ['*'] = 'FilePaletteMarkedFile',
}

--- Get the entry maker
---@param displayer function # The displayer
local function get_entry_maker(displayer)
    ---@param entry ui.file_palette.Entry
    local make_display = function(entry)
        local icon, hl = icons.get_file_icon(entry.filename)
        return displayer {
            { icon, hl },
            { entry.short_name .. ':' .. entry.lnum, hl_map[entry.type] or hl_map['*'] },
        }
    end

    ---@param entry ui.file_palette.Entry
    return function(entry)
        return table.merge(entry, {
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

    local displayer = get_displayer(opts)
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
        })
        :find()
end

--- Open the command palette
---@param opts ui.file_palette.Options|nil # The options
function M.show_file_palette(opts)
    opts = opts or {}

    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    opts.column_separator = opts.column_separator or ''

    show_file_palette(opts)
end

ide.cmd.register('Files', function()
    M.show_file_palette()
end, { desc = 'Show file palette' })

keys.map('n', '<F3>', '<cmd>Files<cr>', { desc = 'Show file palette' })
keys.map('n', '<leader>b', '<cmd>Files<cr>', { desc = 'Show file palette' })

return M

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local actions = require 'telescope.actions'
local themes = require 'telescope.themes'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local strings = require 'plenary.strings'
local config = require('telescope.config').values
local utils = require 'core.utils'
local icons = require 'ui.icons'

local M = {}

---@alias ui.select.SelectEntry string|number|boolean|(string|number|boolean)[]) # An entry in the list of items to select from
---@alias ui.select.SelectCallback fun(entry?: ui.select.SelectEntry, index?: integer) # The callback to call when an item is selected
---@alias ui.select.SelectHighlighter fun(entry: ui.select.SelectEntry, index: integer, col_index: number): string|nil # The highlighter to use for the entrygh
---@alias ui.select.SelectOpts { prompt?: string, at_cursor?: boolean, separator?: string, callback?: ui.select.SelectCallback, highlighter?: ui.select.SelectHighlighter, index_fields?: integer[], width?: number, height?: number }

--- Select an item from a list of items
---@param items ui.select.SelectEntry[] # The list of items to select from
---@param opts? ui.select.SelectOpts # The options for the select
function M.advanced(items, opts)
    opts = opts or {}

    local callback = opts.callback or function(entry)
        utils.warn('No handler defined, selected: ' .. vim.inspect(entry))
    end
    opts.callback = nil

    local separator = opts.separator or (' ' .. icons.Symbols.ColumnSeparator .. ' ')
    opts.separator = nil

    local highlighter = opts.highlighter or function()
        return nil
    end
    opts.highlighter = nil

    -- extract the prompt
    local prompt = opts.prompt or 'Select one of'
    if prompt:sub(-1, -1) == ':' then
        prompt = prompt:sub(1, -2)
    end
    prompt = string.gsub(prompt, '\n', ' ')

    -- normalize items
    ---@type (string|number|boolean)[][]
    local proc_items = {}
    for _, item in ipairs(items) do
        if type(item) == 'string' or type(item) == 'number' or type(item) == 'boolean' then
            table.insert(proc_items, { item })
        elseif vim.tbl_islist(item) and #item > 0 then
            table.insert(proc_items, item)
        else
            error(string.format('Invalid or unsupported entry: %s', vim.inspect(item)))
        end
    end

    if #proc_items == 0 then
        error 'No items to select from'
    end

    -- validate items and obtain the max lengths of all columns
    local item_length = #proc_items[1]

    ---@type number[]
    local max_lengths = vim.tbl_map(function(item)
        return strings.strdisplaywidth(tostring(item))
    end, proc_items[1])

    for _, item in ipairs(proc_items) do
        if #item ~= item_length then
            error(string.format('All items should be of the same length %d: %s', item_length, vim.inspect(item)))
        end

        for i, field in ipairs(item) do
            max_lengths[i] = math.max(max_lengths[i], strings.strdisplaywidth(field))
        end
    end

    -- build the display function
    local displayer = entry_display.create {
        separator = separator,
        items = vim.tbl_map(function(w)
            return { width = w }
        end, max_lengths),
    }

    local display = function(e)
        local mapped = {}
        for i, field in ipairs(e.value) do
            table.insert(mapped, { field, highlighter(e.value, e.index, i) })
        end

        return displayer(mapped)
    end

    local dd = opts.at_cursor
            and themes.get_cursor(vim.tbl_extend('force', opts, {
                layout_config = { width = opts.width or 0.2, height = opts.height or 0.3 },
            }))
        or themes.get_dropdown(vim.tbl_extend('force', opts, {
            layout_config = { width = opts.width or 0.3, height = opts.height or 0.4 },
        }))

    opts.index_fields = opts.index_fields or { 1 }
    local function make_ordinal(entry)
        local ordinal = ''
        for _, index in ipairs(opts.index_fields) do
            ordinal = ordinal .. icons.Symbols.ColumnSeparator .. tostring(entry[index])
        end

        return ordinal
    end

    pickers
        .new(dd, {
            prompt_title = prompt,
            finder = finders.new_table {
                results = proc_items,
                entry_maker = function(e)
                    return {
                        value = e,
                        display = display,
                        ordinal = make_ordinal(e),
                    }
                end,
            },
            sorter = config.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    callback(selection.value, selection.index)
                end)

                return true
            end,
        })
        :find()
end

---@alias ui.select.CommandItem { name: string, command: string|function, desc?: string, hl?: string}

--- Selects and executes a command
---@param commands ui.select.CommandItem[] # The list of commands to select from
---@param opts? { prompt?: string, at_cursor?: boolean, width?: number, height?: number }
function M.command(commands, opts)
    assert(vim.tbl_islist(commands))

    ---@type (string|integer)[][]
    local items = {}
    for i, command in ipairs(commands) do
        assert(type(command.command) == 'string' or type(command.command) == 'function')

        ---@type string[]
        local entry = {}

        table.insert(entry, i)
        table.insert(entry, command.name)
        table.insert(entry, command.desc and command.desc or type(command.command) == 'string' and command.command or 'function')

        table.insert(items, entry)
    end

    M.advanced(
        items,
        vim.tbl_extend('force', opts or {}, {
            prompt = 'Select command:',
            separator = ' ',
            highlighter = function(_, index, col_index)
                if col_index == 2 then
                    return commands[index].hl or 'NormalMenuItem'
                end

                return 'Comment'
            end,
            callback = function(_, index)
                local command = commands[index].command

                if type(command) == 'string' then
                    vim.cmd(command)
                else
                    command()
                end
            end,
            index_fields = { 1, 2 },
        })
    )
end

return M

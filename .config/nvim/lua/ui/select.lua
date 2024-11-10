local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local actions = require 'telescope.actions'
local themes = require 'telescope.themes'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local strings = require 'plenary.strings'
local config = require('telescope.config').values
local icons = require 'ui.icons'

local M = {}

-- TODO: fix bug pressing enter without a selection
-- E5108: Error executing lua: /Users/alex/.config/nvim/lua/ui/select.lua:180: attempt to index local 'selection' (a nil value)
--stack traceback:
--	/Users/alex/.config/nvim/lua/ui/select.lua:180: in function 'run_replace_or_original'
--	...re/nvim/lazy/telescope.nvim/lua/telescope/actions/mt.lua:65: in function 'key_func'
--	...hare/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua:293: in function <...hare/nvim/lazy/telescope.nvim/lua/telescope/mappings.lua:292>

---@alias ui.select.SelectEntry
---|string
---|number
---|boolean
---|(string|number|boolean)[]) # An entry in the list of items to select from

---@alias ui.select.SelectCallback
---| fun(entry: ui.select.SelectEntry, index: integer) # The callback to call when an item is selected
---@alias ui.select.SelectHighlighter
---| fun(entry: ui.select.SelectEntry, index: integer, col_index: number): string|nil # The highlighter to use for entry

---@class (exact) ui.select.SelectOpts # The options for the select
---@field prompt string|nil # The prompt to display
---@field at_cursor boolean|nil # Whether to display the select at the cursor
---@field separator string|nil # The separator to use between columns
---@field callback ui.select.SelectCallback|nil # The callback to call when an item is selected
---@field highlighter ui.select.SelectHighlighter|nil # The highlighter to use for the entry
---@field index_fields integer[]|nil # The fields to use for the index
---@field width number|nil # The width of the select
---@field height number|nil # The height of the select

local h_padding = 14
local v_padding = 4

--- Select an item from a list of items
---@param items ui.select.SelectEntry[] # The list of items to select from
---@param opts ui.select.SelectOpts|nil # The options for the select
function M.advanced(items, opts)
    opts = opts or {}

    local callback = opts.callback
        or function(entry)
            vim.warn('No handler defined, selected: ' .. vim.inspect(entry))
        end
    opts.callback = nil

    local separator = opts.separator or (' ' .. icons.Symbols.ColumnSeparator .. ' ')
    opts.separator = nil

    opts.highlighter = opts.highlighter or function()
        return nil
    end

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
        elseif vim.islist(item) and #item > 0 then
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
    local max_width = strings.strdisplaywidth(prompt) + h_padding

    ---@type number[]
    local max_lengths = vim.iter(proc_items[1])
        :map(
            ---@param item (string|number|boolean)
            function(item)
                local l = strings.strdisplaywidth(tostring(item))
                max_width = math.max(max_width, l)
                return l
            end
        )
        :totable()

    for _, item in ipairs(proc_items) do
        if #item ~= item_length then
            error(string.format('All items should be of the same length %d: %s', item_length, vim.inspect(item)))
        end

        for i, field in ipairs(item) do
            max_lengths[i] = math.max(max_lengths[i], strings.strdisplaywidth(tostring(field)))
        end

        local line_width = strings.strdisplaywidth(table.concat(item, separator)) + h_padding
        max_width = math.max(max_width, line_width)
    end

    local max_height = math.min(vim.o.pumheight, #proc_items) + v_padding

    -- build the display function
    local displayer = entry_display.create {
        separator = separator,
        items = vim.iter(max_lengths)
            :map(
                ---@param w number
                function(w)
                    return { width = w }
                end
            )
            :totable(),
    }

    local display = function(e)
        local mapped = {}
        for i, field in ipairs(e.value) do
            table.insert(mapped, { field, opts.highlighter(e.value, e.index, i) })
        end

        return displayer(mapped)
    end

    local dd = opts.at_cursor
            and themes.get_cursor(vim.tbl_extend('force', opts, {
                layout_config = { width = opts.width or max_width, height = opts.height or max_height },
            }))
        or themes.get_dropdown(vim.tbl_extend('force', opts, {
            layout_config = { width = opts.width or max_width, height = opts.height or max_height },
        }))

    opts.index_fields = opts.index_fields or { 1 }
    local function make_ordinal(entry)
        local ordinal = ''

        for _, index in ipairs(opts.index_fields) do
            local v = tostring(entry[index])
            if v == '' then
                v = '\u{FFFFF}'
            end

            ordinal = ordinal .. '\u{FFFFE}' .. v
        end

        return ordinal
    end

    table.sort(proc_items, function(a, b)
        return make_ordinal(a) < make_ordinal(b)
    end)

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
    assert(vim.islist(commands))

    ---@type (string|integer)[][]
    local items = {}
    for i, command in ipairs(commands) do
        assert(type(command.command) == 'string' or type(command.command) == 'function')

        ---@type string[]
        local entry = {}

        table.insert(entry, i)
        table.insert(entry, command.name)
        table.insert(
            entry,
            command.desc and command.desc or type(command.command) == 'string' and command.command or 'function'
        )

        table.insert(items, entry)
    end

    M.advanced(
        items,
        vim.tbl_extend('keep', opts or {}, {
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

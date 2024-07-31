local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local utils = require 'core.utils'
local keys = require 'core.keys'
local icons = require 'ui.icons'

---@class ui.command_palette.Options
---@field mode string|nil # List of modes to get items for
---@field buffer number|nil # The buffer to get the items from, 0, or nil for current buffer
---@field column_separator string|nil # The column separator

---@class vim.CommandDesc # Command description
---@field name string # Command name
---@field nargs string # Number of arguments
---@field definition string # Command definition
---@field bang boolean # Command supports bang
---@field bar boolean # Command supports bar
---@field range string|nil # Command range definition
---@field complete function|nil # Command completion

--- Get all commands
---@param opts ui.command_palette.Options # The options
---@return vim.CommandDesc[] # List of commands
local function get_commands(opts)
    assert(type(opts) == 'table')

    ---@type vim.CommandDesc[]
    local commands = vim.tbl_values(vim.api.nvim_get_commands {})
    ---@type vim.CommandDesc[]
    local buffer_commands = vim.tbl_values(vim.api.nvim_buf_get_commands(opts.buffer, {}))

    local is_visual = utils.is_visual_mode(opts.mode)

    ---@type vim.CommandDesc[]
    local all = vim.iter(vim.list_extend(commands, buffer_commands))
        :filter(
            ---@param cmd vim.CommandDesc
            function(cmd)
                if type(cmd) ~= 'table' then
                    return false
                end

                local works_in_visual = cmd.range and cmd.range ~= ''
                return (works_in_visual and is_visual) or opts.mode == 'n'
            end
        )
        :totable()

    return all
end

---@class vim.KeymapDesc # Keymap description
---@field mode string # Mode
---@field lhs string # Left-hand side
---@field rhs string # Right-hand side
---@field desc string|nil # Description
---@field buffer number # Buffer
---@field callback function # Callback
---@field lnum number # Line number
---@field abbr number # Abbreviation (boolean)
---@field expr number # Expression (boolean)
---@field noremap number # No remap (boolean)
---@field silent number # Silent (boolean)

--- Get all keymaps
---@param opts ui.command_palette.Options # The options
---@return vim.KeymapDesc[] # List of keymaps
local function get_keymaps(opts)
    assert(type(opts) == 'table')

    ---@type vim.api.keyset.keymap[]
    local all = {}

    vim.list_extend(all, vim.api.nvim_get_keymap(opts.mode))
    vim.list_extend(all, vim.api.nvim_buf_get_keymap(opts.buffer, opts.mode))

    ---@type table<string, vim.KeymapDesc>
    local keymaps = {}

    for _, keymap in ipairs(all) do
        ---@cast keymap { buffer: number, mode: string, lhs: string, rhs: string}
        local keymap_key = keymap.buffer .. keymap.mode .. keymap.lhs

        if not keymaps[keymap_key] then
            keymaps[keymap_key] = keymap
        end
    end

    return vim.tbl_values(keymaps)
end

---@class ui.command_palette.Entry
---@field type 'command'|'keymap' # Entry type
---@field name string|nil # The name of the entry
---@field attrs string # The attributes of the entry
---@field desc string # The description of the entry
---@field original vim.CommandDesc|vim.KeymapDesc # The original entry

--- Get all command palette items
---@param opts ui.command_palette.Options # The options
---@return ui.command_palette.Entry[] # List of items
local function get_items(opts)
    assert(type(opts) == 'table')

    local commands = get_commands(opts)
    local keymaps = get_keymaps(opts)

    ---@type ui.command_palette.Entry[]
    local items = {}

    for _, cmd in ipairs(commands) do
        -- attributes
        local attrs = cmd.nargs or '0'

        if cmd.bang then
            attrs = attrs .. '!'
        end

        if cmd.complete then
            attrs = attrs .. icons.TUI.LineEnd
        end

        if cmd.range and cmd.range ~= '' then
            attrs = attrs .. icons.TUI.Ellipsis
        end

        table.insert(items, {
            type = 'command',
            name = cmd.name,
            attrs = attrs,
            desc = cmd.definition:gsub('\n', ' '),
            original = cmd,
        })
    end

    for _, keymap in ipairs(keymaps) do
        -- attributes
        local attrs = keymap.mode
        if keymap.noremap ~= 0 then
            attrs = attrs .. '*'
        end
        if keymap.buffer ~= 0 then
            attrs = attrs .. '@'
        end

        -- description
        local desc = (keymap.desc or keys.format_term_codes(keymap.rhs or '')):gsub('\n', '\\n')
        if keymap.callback and not keymap.desc then
            -- TODO: this seems to need my love
            desc = require('telescope.actions.utils')._get_anon_function_name(debug.getinfo(keymap.callback))
        end

        table.insert(items, {
            type = 'keymap',
            name = keys.format_term_codes(keymap.lhs),
            attrs = attrs,
            desc = desc:gsub('\n', ' '),
            original = keymap,
        })
    end

    return items
end
--- Gets the displayer
---@param name_col_width number # The width of the name column
---@param attr_col_width number # The width of the attributes column
---@param opts ui.command_palette.Options
local function get_displayer(name_col_width, attr_col_width, opts)
    return entry_display.create {
        separator = opts.column_separator,
        items = {
            { width = name_col_width },
            { width = attr_col_width },
            { remaining = true },
        },
    }
end

--- Get the entry maker
---@param displayer function # The displayer
local function get_entry_maker(displayer)
    ---@param entry ui.command_palette.Entry
    local make_display = function(entry)
        local main_hl = 'CommandPaletteCommand'

        if entry.type == 'keymap' then
            main_hl = 'CommandPaletteKeymap'
        end

        return displayer {
            { entry.name, main_hl },
            { entry.attrs, 'TelescopeResultsComment' },
            entry.desc,
        }
    end

    ---@param entry ui.command_palette.Entry
    return function(entry)
        return utils.tbl_merge(entry, {
            ordinal = entry.attrs .. ' ' .. entry.name,
            display = make_display,
        })
    end
end

---@class ui.command_palette
local M = {}

--- Open the command palette (internal)
---@param opts ui.command_palette.Options # The options
local function show_command_palette(opts)
    assert(type(opts) == 'table')

    local items = get_items(opts)

    local name_col_width = 0
    local attrs_col_width = 0

    for _, item in ipairs(items) do
        name_col_width = math.max(name_col_width, #item.name)
        attrs_col_width = math.max(attrs_col_width, #item.attrs)
    end

    local displayer = get_displayer(name_col_width + 1, attrs_col_width + 1, opts)
    local entry_maker = get_entry_maker(displayer)

    pickers
        .new(opts, {
            prompt_title = 'Palette',
            finder = finders.new_table {
                results = items,
                entry_maker = entry_maker,
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    ---@cast selection ui.command_palette.Entry|nil
                    if selection == nil then
                        utils.warn 'Nothing has been selected'
                        return
                    end

                    if selection.type == 'command' then
                        actions.close(prompt_bufnr)
                        local command = selection.original --[[@as vim.CommandDesc]]

                        local cmd = string.format([[:%s ]], command.name)
                        if command.nargs == '0' then
                            local cr = vim.api.nvim_replace_termcodes('<cr>', true, false, true)
                            cmd = cmd .. cr
                        elseif command.complete then
                            cmd = cmd .. '<Tab>'
                        end

                        vim.cmd.stopinsert()
                        if utils.is_visual_mode(opts.mode) then
                            keys.feed 'gv'
                        end

                        keys.feed(cmd, 'nt')
                    elseif selection.type == 'keymap' then
                        local keymap = selection.original --[[@as vim.KeymapDesc]]

                        keys.feed(keymap.lhs, 't')
                        return actions.close(prompt_bufnr)
                    end
                end)

                return true
            end,
        })
        :find()
end

--- Open the command palette
---@param opts ui.command_palette.Options|nil # The options
function M.show_command_palette(opts)
    opts = opts or {}

    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()
    opts.column_separator = opts.column_separator or (' ' .. icons.Symbols.ColumnSeparator .. ' ')
    opts.mode = opts.mode or vim.fn.mode()

    if utils.is_visual_mode(opts.mode) then
        keys.feed '<esc>'

        vim.schedule(function()
            show_command_palette(opts)
        end)
    else
        show_command_palette(opts)
    end
end

keys.map({ 'n', 'x', 'i' }, '<F2>', M.show_command_palette, { desc = 'Show command palette' })

return M

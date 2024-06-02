local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local utils = require 'core.utils'
local icons = require 'ui.icons'

---@class vim.CommandDesc # Command description
---@field name string # Command name
---@field nargs string # Number of arguments
---@field definition string # Command definition
---@field bang boolean # Command supports bang
---@field bar boolean # Command supports bar
---@field range string|nil # Command range definition
---@field complete function|nil # Command completion

--- Get all commands
---@param buffer number|nil # The buffer to get the commands from, 0, or nil for current buffer
---@param modes string[] # List of modes to get the commands from
---@return vim.CommandDesc # List of commands
local function get_commands(buffer, modes)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type vim.CommandDesc[]
    local commands = vim.tbl_values(vim.api.nvim_get_commands {})
    ---@type vim.CommandDesc[]
    local buffer_commands = vim.tbl_values(vim.api.nvim_buf_get_commands(buffer, {}))

    local include_visual = vim.tbl_contains(modes, 'v')
    local include_normal = vim.tbl_contains(modes, 'n')

    return vim.tbl_filter(
        ---@param cmd vim.CommandDesc
        function(cmd)
            if cmd == nil then
                return false
            end

            local works_in_visual = cmd.range and cmd.range ~= ''

            return (works_in_visual and include_visual) or include_normal
        end,
        vim.list_extend(commands, buffer_commands)
    )
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
---@param buffer number|nil # The buffer to get the keymaps from, 0, or nil for current buffer
---@param modes string[] # List of modes to get the keymaps from
---@return vim.KeymapDesc[] # List of keymaps
local function get_keymaps(buffer, modes)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type vim.api.keyset.keymap[]
    local all = {}
    for _, mode in pairs(modes) do
        vim.list_extend(all, vim.api.nvim_get_keymap(mode))
        vim.list_extend(all, vim.api.nvim_buf_get_keymap(buffer, mode))
    end

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
---@param buffer number|nil # The buffer to get the items from, 0, or nil for current buffer
---@param keymap_modes string[] # List of modes to get the keymaps from
---@return ui.command_palette.Entry[] # List of items
local function get_items(buffer, keymap_modes)
    local commands = get_commands(buffer, keymap_modes)
    local keymaps = get_keymaps(buffer, keymap_modes)

    ---@type ui.command_palette.Entry[]
    local items = {}
    for _, cmd in ipairs(commands) do
        -- attributes
        local attrs = ''

        if cmd.nargs == '?' then
            attrs = attrs .. 'at most one argument'
        elseif cmd.nargs == '*' then
            attrs = attrs .. 'many arguments'
        elseif cmd.nargs == '+' then
            attrs = attrs .. '1 or more arguments'
        elseif cmd.nargs == '0' then
            attrs = attrs .. 'no arguments'
        elseif cmd.nargs == '1' then
            attrs = attrs .. 'one argument'
        else
            attrs = attrs .. cmd.nargs .. ' arguments'
        end

        if cmd.bang then
            attrs = attrs .. ' !'
        end

        if cmd.range and cmd.range ~= '' then
            attrs = attrs .. ' '
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
        local desc = (keymap.desc or keymap.rhs or ''):gsub('\n', '\\n')
        if keymap.callback and not keymap.desc then
            desc = require('telescope.actions.utils')._get_anon_function_name(debug.getinfo(keymap.callback))
        end

        table.insert(items, {
            type = 'keymap',
            name = keymap.lhs,
            attrs = attrs,
            desc = desc,
            original = keymap,
        })
    end

    return items
end

---@class ui.command_palette.Options
---@field key_modes string[] # List of modes to get the keymaps from
---@field buffer number|nil # The buffer to get the items from, 0, or nil for current buffer
---@field column_separator string|nil # The column separator

--- Gets the displayer
---@param name_col_width number # The width of the name column
---@param attr_col_width number # The width of the attributes column
---@param opts ui.command_palette.Options
local function get_displayer(name_col_width, attr_col_width, opts)
    --max_len_lhs = math.max(max_len_lhs, #utils.format_term_codes(keymap.lhs))

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
        return displayer {
            { entry.name, 'TelescopeResultsIdentifier' },
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
---@param mode string # The current mode
---@param opts ui.command_palette.Options # The options
local function show_command_palette(mode, opts)
    assert(type(opts) == 'table')

    opts.column_separator = opts.column_separator or (' ' .. icons.Symbols.ColumnSeparator .. ' ')

    local items = get_items(opts.buffer, opts.key_modes)

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
                results = get_items(opts.buffer, opts.key_modes),
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
                        if mode == 'v' then
                            utils.feed_keys 'gv'
                        end

                        utils.feed_keys(cmd, 'nt')
                    elseif selection.type == 'keymap' then
                        local keymap = selection.original --[[@as vim.KeymapDesc]]

                        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keymap.lhs, true, false, true), 't', true)
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

    local mode = vim.fn.mode()

    if opts.key_modes == nil then
        if mode == 'n' then
            opts.key_modes = { 'n' }
        elseif mode == 'i' then
            opts.key_modes = { 'i' }
        elseif mode == 's' then
            opts.key_modes = { 's' }
        elseif mode == 'v' or mode == 'V' then
            opts.key_modes = { 'v' }
        else
            opts.key_modes = { 'n', 'i', 'c', 'x' }
        end
    end

    if mode == 'v' then
        utils.feed_keys '<esc>'

        vim.schedule(function()
            show_command_palette(mode, opts)
        end)
    else
        show_command_palette(mode, opts)
    end
end

return M

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local entry_display = require 'telescope.pickers.entry_display'
local utils = require 'core.utils'

---@class vim.CommandDesc # Command description
---@field name string # Command name
---@field nargs string # Number of arguments
---@field definition string # Command definition

---@class vim.KeymapDesc # Keymap description
---@field mode string # Mode
---@field lhs string # Left-hand side
---@field rhs string # Right-hand side
---@field desc string|nil # Description
---@field buffer number # Buffer

---@alias ui.command_palette.Entry vim.CommandDesc|vim.KeymapDesc # The command palette entry

--- Get all commands
---@param buffer number|nil # The buffer to get the commands from, 0, or nil for current buffer
---@return vim.CommandDesc # List of commands
local function get_commands(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type vim.CommandDesc[]
    local commands = vim.tbl_values(vim.api.nvim_get_commands {})
    ---@type vim.CommandDesc[]
    local buffer_commands = vim.tbl_values(vim.api.nvim_buf_get_commands(buffer, {}))

    return vim.tbl_filter(
        ---@param cmd vim.CommandDesc
        function(cmd)
            return cmd ~= nil
        end,
        vim.list_extend(commands, buffer_commands)
    )
end

--- Get all keymaps
---@param buffer number|nil # The buffer to get the keymaps from, 0, or nil for current buffer
---@param modes string[] # List of modes to get the keymaps from
---@return vim.KeymapDesc[], integer # List of keymaps, maximum length of the left-hand side
local function get_keymaps(buffer, modes)
    buffer = buffer or vim.api.nvim_get_current_buf()

    ---@type table<string, boolean>
    local keymap_encountered = {}
    ---@type vim.KeymapDesc[]
    local keymaps_table = {}
    local max_len_lhs = 0

    ---@param keymaps vim.KeymapDesc[]
    local function extract_keymaps(keymaps)
        for _, keymap in pairs(keymaps) do
            local keymap_key = keymap.buffer .. keymap.mode .. keymap.lhs
            if not keymap_encountered[keymap_key] then
                keymap_encountered[keymap_key] = true
                table.insert(keymaps_table, keymap)
                max_len_lhs = math.max(max_len_lhs, #utils.format_term_codes(keymap.lhs))
            end
        end
    end

    for _, mode in pairs(modes) do
        extract_keymaps(vim.api.nvim_get_keymap(mode))
        extract_keymaps(vim.api.nvim_buf_get_keymap(buffer, mode))
    end

    return keymaps_table, max_len_lhs + 1
end

--- Get all command palette items
---@param buffer number|nil # The buffer to get the items from, 0, or nil for current buffer
---@param keymap_modes string[]|nil # List of modes to get the keymaps from
---@return ui.command_palette.Entry[] # List of items
local function get_items(buffer, keymap_modes)
    local commands = get_commands(buffer)
    local keymaps = get_keymaps(buffer, keymap_modes or { 'n', 'i', 'c', 'x' })

    return vim.list_extend(commands, keymaps)
end

local handle_entry_index = function(opts, t, k)
    local override = ((opts or {}).entry_index or {})[k]
    if not override then
        return
    end

    local val, save = override(t, opts)
    if save then
        rawset(t, k, val)
    end
    return val
end

local set_default_entry_mt = function(tbl, opts)
    return setmetatable({}, {
        __index = function(t, k)
            local override = handle_entry_index(opts, t, k)
            if override then
                return override
            end

            -- Only hit tbl once
            local val = tbl[k]
            if val then
                rawset(t, k, val)
            end

            return val
        end,
    })
end

local function get_entry_maker(opts)
    local displayer = entry_display.create {
        separator = '▏',
        items = {
            { width = 10 },
            { width = 4 },
            { remaining = true },
        },
    }

    local function get_desc(entry)
        if entry.callback and not entry.desc then
            return require('telescope.actions.utils')._get_anon_function_name(debug.getinfo(entry.callback))
        end

        return (entry.desc or entry.rhs):gsub('\n', '\\n')
    end

    local function get_lhs(entry)
        return utils.format_term_codes(entry.lhs)
    end
    local function get_attr(entry)
        local ret = ''
        if entry.value.noremap ~= 0 then
            ret = ret .. '*'
        end
        if entry.value.buffer ~= 0 then
            ret = ret .. '@'
        end
        return ret
    end

    ---@param entry ui.command_palette.Entry
    local make_display = function(entry)
        if entry.name then
            return displayer {
                entry.name,
                entry.nargs,
                entry.definition:gsub('\n', ' '),
            }
        else
            return displayer {
                entry.mode,
                get_lhs(entry),
                get_attr(entry),
                get_desc(entry),
            }
        end
    end

    return function(entry)
        if entry.name then
            ---@cast entry vim.CommandDesc
            return set_default_entry_mt({
                name = entry.name,
                nargs = entry.nargs,
                definition = entry.definition,
                --
                value = entry,
                ordinal = entry.name,
                display = make_display,
            }, opts)
        elseif entry.lhs then
            ---@cast entry vim.KeymapDesc
            local desc = get_desc(entry)
            local lhs = get_lhs(entry)

            return set_default_entry_mt({
                mode = entry.mode,
                lhs = lhs,
                desc = desc,
                valid = entry ~= '',
                value = entry,
                ordinal = entry.mode .. ' ' .. lhs .. ' ' .. desc,
                display = make_display,
            }, opts)
        end
    end
end

local function command_palette(opts)
    opts.modes = vim.F.if_nil(opts.modes, { 'n', 'i', 'c', 'x' })
    opts.show_plug = vim.F.if_nil(opts.show_plug, true)
    opts.only_buf = vim.F.if_nil(opts.only_buf, false)

    pickers
        .new(opts, {
            prompt_title = 'Palette',
            finder = finders.new_table {
                results = get_items(),
                entry_maker = get_entry_maker(opts),
            },
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    if selection == nil then
                        utils.warn 'Nothing has been selected'
                        return
                    end

                    if selection.value.type == 'command' then
                        actions.close(prompt_bufnr)

                        local val = selection.value
                        local cmd = string.format([[:%s ]], val.name)

                        if val.nargs == '0' then
                            local cr = vim.api.nvim_replace_termcodes('<cr>', true, false, true)
                            cmd = cmd .. cr
                        end

                        vim.cmd [[stopinsert]]
                        vim.api.nvim_feedkeys(cmd, 'nt', false)
                    elseif selection.value.type == 'keymap' then
                        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(selection.value.lhs, true, false, true), 't', true)
                        return actions.close(prompt_bufnr)
                    end
                end)

                return true
            end,
        })
        :find()
end

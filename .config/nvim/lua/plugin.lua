--- Provides functionality for interacting with plugins.
---@class plugins
local M = {}

--- Checks if a plugin is available
---@param name string # the name of the plugin
---@return boolean # true if the plugin is available, false otherwise
function M.has(name)
    xassert { name = { name, { 'string', ['>'] = 0 } } }

    if package.loaded['lazy'] then
        return require('lazy.core.config').spec.plugins[name] ~= nil
    end

    return false
end

--- Returns the configuration of a plugin
---@param name string # the name of the plugin
---@return table<string, any>|nil # the configuration of the plugin
function M.config(name)
    xassert { name = { name, { 'string', ['>'] = 0 } } }

    if package.loaded['lazy'] then
        local plugin = require('lazy.core.config').spec.plugins[name]
        return plugin and require('lazy.core.plugin').values(plugin, 'opts', false)
    end
end

---@class plugins.require_online_opts # Options to require online plugins.
---@field branch string|nil # the branch to clone.
---@field include_blobs boolean|nil # whether to include blobs.
---@field quit boolean|nil # whether to quit the process if the plugin is not available.

-- Require a plugin from an online repository.
---@param url string # the URL of the repository.
---@param path string # the path to clone the repository to.
---@param opts plugins.require_online_opts|nil # the options to require the plugin.
---@return boolean # `true` if the plugin is available, `false` otherwise.
function M.require_online(url, path, opts)
    opts = table.merge(opts, { branch = 'stable', include_blobs = false, quit = true })

    xassert {
        url = { url, { 'string', ['>'] = 0 } },
        path = { path, { 'string', ['>'] = 0 } },
        opts = {
            opts,
            {
                branch = { 'string', ['>'] = 0 },
                include_blobs = 'boolean',
                quit = 'boolean',
            },
        },
    }

    local actual_path = ide.fs.join_paths(ide.fs.DATA_DIRECTORY, path)

    if not ide.fs.directory_exists(actual_path) then
        local result = vim.system({
            'git',
            'clone',
            (not opts.include_blobs) and '--filter=blob:none' or nil,
            url,
            opts.branch and string.format('--branch=%s', opts.branch) or nil,
            actual_path,
        }):wait()

        if result.code ~= 0 then
            local message = string.format('failed to clone the repository `%s`: %s', url, result.stderr)
            if opts.quit then
                ide.process.fatal(message)
            else
                ide.tui.error(message)
            end

            return false
        end
    end

    vim.opt.rtp:prepend(actual_path)
    return true
end

-- Triggers when a plugin is loaded.
---@param name string # the name of the plugin.
---@param callback fun(args: vim.auto_command_event_arguments) # the callback to trigger.
---@return fun() # the unsubscribe function.
function M.on_loaded(name, callback)
    xassert {
        name = { name, { 'string', ['>'] = 0 } },
        fn = { callback, { 'callable' } },
    }

    return ide.sched.subscribe_event('@LazyLoad', function(args)
        if args.data == name then
            callback(args)
        end
    end, {
        description = string.format('Triggers when the plugin `%s` is loaded.', name),
        patterns = { name },
        group = string.format('plugin.loaded.%s', name),
        once = true,
    })
end

-- Creates a plugin slot.
---@param name string # the name of the plugin slot.
---@return table # the plugin slot.
local function define_plugin_slot(name)
    xassert { name = { name, { 'string', ['>'] = 0 } } }

    local subscribe, trigger = ide.sched.define_event('PluginRegistered_' .. name)
    local plugins = {}

    return {
        plugins = plugins,
        register = function(plugin)
            xassert {
                plugin = {
                    plugin,
                    {
                        status = 'callable',
                        run = 'callable',
                    },
                },
            }

            if table.list_any(plugins, plugin) then
                return
            end

            table.insert(plugins, plugin)
            trigger()
        end,
        on_registered = function(...)
            local res = subscribe(...)

            if not table.is_empty(plugins) then
                trigger()
            end

            return res
        end,
    }
end

---@class (exact) formatter_plugin # Describes a formatter plugin.
---@field status fun(buffer: buffer): table<string, boolean> # gets the status of the supported formatters.
---@field run fun(buffer: buffer, callback: fun(result: boolean|string)) # runs the formatters.

-- Formatter plugin slot.
---@class (exact) formatter_plugin_slot
---@field plugins formatter_plugin[] # the registered formatter plugins.
---@field register fun(plugin: formatter_plugin) # registers a formatter plugin.
---@field on_registered fun(callback: fun()) # triggers when a formatter plugin is registered.
M.formatter = define_plugin_slot 'Formatter'

---@class (exact) linter_plugin # Describes a linting plugin.
---@field status fun(buffer: buffer): table<string, boolean> # gets the status of the supported linters.
---@field run fun(buffer: buffer, callback: fun(result: boolean|string)) # runs the linters.

-- Linter plugin slot.
---@class (exact) linter_plugin_slot
---@field plugins linter_plugin[] # the registered linter plugins.
---@field register fun(plugin: linter_plugin) # registers a linter plugin.
---@field on_registered fun(callback: fun()) # triggers when a linter plugin is registered.
M.linter = define_plugin_slot 'Linter'

---@module 'symb'

---@class (exact) symbol_provider_plugin # Describes an icon provider plugin.
---@field get_file_symbol fun(path: string): symbol # gets the icon for a file.
---@field get_file_type_symbol fun(file_type: string): symbol # gets the icon for a file type.

-- Symbol provider plugin slot.
---@class (exact) symbol_provider_plugin_slot
---@field plugins symbol_provider_plugin[] # the registered symbol provider plugins.
---@field register fun(plugin: symbol_provider_plugin) # registers a symbol provider plugin.
---@field on_registered fun(callback: fun()) # triggers when a symbol provider plugin is registered.
M.symbol_provider = define_plugin_slot 'SymbolProvider'

---@alias select_ui_row string[] # The row of a select plugin.
---@alias select_ui_rows select_ui_row[] # The rows of a select plugin.

---@alias select_ui_callback # The callback to call when an item is selected.
---| fun(item: select_ui_row, row: integer)

---@alias select_ui_highlighter # The highlighter to use for entry.
---| fun(row: select_ui_row, row: integer, col: integer): string|nil

---@class (exact) select_ui_options # The options for the select.
---@field prompt string|nil # the prompt to display.
---@field at_cursor boolean|nil # whether to display the select at the cursor.
---@field separator string|nil # the separator to use between columns.
---@field callback select_ui_callback|nil # the callback to call when an item is selected.
---@field highlighter select_ui_highlighter|nil # the highlighter to use for the entry.
---@field index_cols integer[]|nil # the fields to use for the index.
---@field width number|nil # the width of the select.
---@field height number|nil # the height of the select.

---@class (exact) select_ui_plugin # Describes a select plugin.
---@field select fun(items: select_ui_rows, opts: select_ui_options): boolean # selects an item from a list of items.

-- Select plugin slot.
---@class (exact) select_ui_plugin_slot
---@field plugins select_ui_plugin[] # the registered select plugins.
---@field register fun(plugin: select_ui_plugin) # registers a select plugin.
---@field on_registered fun(callback: fun()) # triggers when a select plugin is registered.
M.select_ui = define_plugin_slot 'SelectUi'

---@class (exact) keymap_plugin_set_options # The options to pass to the keymap.
---@field mode string|string[] # the mode(s) to map the key in.
---@field buffer buffer|nil # whether the keymap is buffer-local.
---@field silent boolean|nil # whether the keymap is silent.
---@field returns_expr boolean|nil # whether the keymap returns an expression.
---@field no_remap boolean|nil # whether the keymap is non-recursive.
---@field no_wait boolean|nil # whether the keymap is non-blocking.
---@field desc string|nil # the description of the keymap.
---@field icon icon|nil # the icon of the keymap.

---@class (exact) keymap_plugin_prefix_options # The options to pass to the keymap.
---@field mode string|string[] # the mode(s) to map the key in.
---@field buffer buffer|nil # whether the keymap is buffer-local.
---@field desc string|nil # the description of the keymap.
---@field icon icon|nil # the icon of the keymap.

---@class (exact) keymap_plugin # Describes a keymap plugin.
---@field set fun(keymap: string, action: string|function, opts: keymap_plugin_set_options|nil) # sets a keymap.
---@field prefix fun(prefix: string,  opts: keymap_plugin_prefix_options|nil) # sets a keymap prefix.

-- Keymap plugin slot.
---@class (exact) keymap_plugin_slot
---@field plugins keymap_plugin[] # the registered keymap plugins.
---@field register fun(plugin: keymap_plugin) # registers a keymap plugin.
---@field on_registered fun(callback: fun()) # triggers when a keymap plugin is registered.
M.keymap = define_plugin_slot 'Keymap'

return table.freeze(M)

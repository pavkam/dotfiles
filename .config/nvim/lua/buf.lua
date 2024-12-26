local icons = require 'icons'

---@class (exact) remove_buffer_options # Options for removing a buffer.
---@field force boolean|nil # whether to force the removal of the buffer.

---@class (exact) buffer # The buffer details.
---@field id integer # the buffer ID.
---@field file_path string|nil # the file path of the buffer.
---@field file_type string # the file type of the buffer.
---@field windows window[] # the window IDs that display this buffer.
---@field is_modified boolean # whether the buffer is modified.
---@field is_listed boolean # whether the buffer is listed.
---@field is_hidden boolean # whether the buffer is hidden.
---@field is_loaded boolean # whether the buffer is loaded.
---@field is_normal boolean # whether the buffer is a normal buffer.
---@field changed_tick integer # the changed tick of the buffer.
---@field cursor position # the cursor position in the buffer.
---@field height integer # the height of the buffer.
---@field diagnostics_at_cursor vim.Diagnostic[] # the diagnostics at the cursor.
---@field auto_formatting_enabled boolean # whether formatting is enabled for the buffer.
---@field auto_linting_enabled boolean # whether linting is enabled for the buffer.
---@field tools buf_tool[] # the tools available for the buffer.
---@field roots string[] # the project roots for the buffer.
---@field root string # the project root for the buffer.
---@field check_changed fun(what: string): boolean # check if the buffer has changed (for a task).
---@field lines fun(start: integer|nil, end_: integer|nil): string[] # get the lines of the buffer.
---@field confirm_saved fun(reason: string|nil): boolean # confirm if the buffer is saved.
---@field remove fun(opts: remove_buffer_options|nil)  # remove the buffer.
---@field remove_others fun(opts: remove_buffer_options|nil) # remove all other buffers.
---@field next_diagnostic fun(next_or_prev: boolean, severity: vim.diagnostic.Severity|nil) # jump to diagnostic.
---@field clear_diagnostics fun(sources: string[]|string|nil) # clear the diagnostics.
---@field format fun() # format the buffer.
---@field lint fun() # lint the buffer.

---@class (exact) create_buffer_options # Options for creating a buffer.
---@field listed boolean|nil # whether the buffer is listed.
---@field scratch boolean|nil # whether the buffer is a scratch buffer.

---@class (exact) buf # Provides information about buffers.
---@field [integer] buffer|nil # the details for a given buffer.
---@field alternate buffer|nil # the alternate buffer.
---@field current buffer # the current buffer.
---@field auto_formatting_enabled boolean # whether formatting is enabled.
---@field auto_linting_enabled boolean # whether linting is enabled.
---@field new fun(opts: create_buffer_options|nil): buffer # create a new buffer.
---@field load fun(file_path: string): buffer|nil # load a buffer from a file.

---@class (exact) buf_tool # The tools available for a buffer.
---@field name string # the name of the tool.
---@field enabled boolean # whether the tool is enabled.
---@field running boolean # whether the tool is running.
---@field type 'formatter'|'linter'|'lsp' # the type of the tool.

---@type config_toggle|nil
local auto_formatting_toggle

---@type config_toggle|nil
local auto_linting_toggle

-- The buffer API.
---@type buf
local M = table.smart {
    entity_ids = vim.api.nvim_list_bufs,
    entity_id_valid = function(id)
        xassert {
            id = { id, { 'nil', 'integer' } },
        }

        return id and vim.api.nvim_buf_is_valid(id) or false
    end,
    entity_properties = {
        windows = {
            ---@param buffer buffer
            get = function(_, buffer)
                local window_ids = vim.fn.getbufinfo(buffer.id)[1].windows
                if not table.is_empty(window_ids) then
                    return table.list_map(window_ids, function(window_id)
                        return ide.win[window_id]
                    end)
                end
            end,
        },
        is_listed = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.bo[buffer.id].buflisted
            end,
            ---@param buffer buffer
            ---@param value boolean
            set = function(_, buffer, value)
                xassert {
                    value = { value, 'boolean' },
                }
                vim.bo[buffer.id].buflisted = value
            end,
        },
        is_hidden = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.fn.getbufinfo(buffer.id)[1].hidden == 1
            end,
        },
        is_loaded = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.api.nvim_buf_is_loaded(buffer.id)
            end,
        },
        is_modified = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.bo[buffer.id].modified
            end,
        },
        is_normal = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return vim.api.nvim_buf_is_valid(buffer.id) and vim.bo[buffer.id].buftype == ''
            end,
        },
        changed_tick = {
            ---@param buffer buffer
            ---@return integer
            get = function(_, buffer)
                return vim.api.nvim_buf_get_changedtick(buffer.id)
            end,
        },
        file_path = {
            ---@param buffer buffer
            ---@return string|nil
            get = function(_, buffer)
                if buffer.is_normal then
                    return ide.fs.expand_path(vim.api.nvim_buf_get_name(buffer.id))
                end

                return nil
            end,
        },
        file_type = {
            ---@param buffer buffer
            ---@return string
            get = function(_, buffer)
                return vim.bo[buffer.id].filetype
            end,
            ---@param buffer buffer
            ---@param value string
            set = function(_, buffer, value)
                xassert {
                    value = { value, { 'string', ['>'] = 0 } },
                }

                vim.bo[buffer.id].filetype = value
            end,
        },
        cursor = {
            ---@param buffer buffer
            ---@return position
            get = function(_, buffer)
                local window = ide.win[vim.fn.bufwinid(buffer.id)]
                if window then
                    return window.cursor
                end

                local row, col = unpack(vim.api.nvim_buf_get_mark(buffer.id, [["]]))

                return { row, col + 1 }
            end,
        },
        height = {
            ---@param buffer buffer
            ---@return integer
            get = function(_, buffer)
                return vim.api.nvim_buf_line_count(buffer.id)
            end,
        },
        diagnostics_at_cursor = {
            ---@param buffer buffer
            ---@return vim.Diagnostic[]
            get = function(_, buffer)
                return vim.diagnostic.get(buffer.id, { lnum = buffer.cursor[1] })
            end,
        },
        auto_formatting_enabled = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return auto_formatting_toggle and auto_formatting_toggle.get(buffer) or false
            end,
        },
        auto_linting_enabled = {
            ---@param buffer buffer
            ---@return boolean
            get = function(_, buffer)
                return auto_linting_toggle and auto_linting_toggle.get(buffer) or false
            end,
        },
        tools = {
            ---@param buffer buffer
            ---@return buf_tool[]
            get = function(_, buffer)
                ---@type buf_tool[]
                local result = {}

                table.list_iterate(vim.lsp.get_clients { bufnr = buffer.id }, function(client)
                    table.insert(result, {
                        name = client.name,
                        enabled = not client.is_stopped(),
                        running = not table.is_empty(client.requests),
                        type = 'lsp',
                    })
                end)

                -- TODO: flat map
                table.list_iterate(ide.plugin.formatter_plugins, function(plugin)
                    for formatter, running in pairs(plugin.status(buffer)) do
                        table.insert(result, {
                            name = formatter,
                            enabled = buffer.auto_formatting_enabled,
                            running = running,
                            type = 'formatter',
                        })
                    end
                end)

                table.list_iterate(ide.plugin.linter_plugins, function(plugin)
                    for linter, running in pairs(plugin.status(buffer)) do
                        table.insert(result, {
                            name = linter,
                            enabled = buffer.auto_linting_enabled,
                            running = running,
                            type = 'linter',
                        })
                    end
                end)

                return result
            end,
        },
        roots = {
            ---@param buffer buffer
            ---@return string[]
            get = function(_, buffer)
                return require('project').roots(buffer.id)
            end,
        },
        root = {
            ---@param buffer buffer
            ---@return string
            get = function(_, buffer)
                return require('project').root(buffer.id)
            end,
        },
    },
    entity_functions = {
        ---@param buffer buffer
        ---@param what string
        ---@return boolean
        check_changed = function(_, buffer, what)
            xassert {
                what = {
                    what,
                    {
                        'string',
                        ['>'] = 0,
                    },
                },
            }

            local name = string.format('check_%s_at_tick', what)
            local buffer_changed_tick = buffer.changed_tick
            local prev_changed_tick = vim.b[buffer.id][name]
            if prev_changed_tick and prev_changed_tick == buffer_changed_tick then
                return false
            end

            vim.b[buffer.id][name] = buffer_changed_tick
            return true
        end,

        ---@param buffer buffer
        ---@param start integer|nil
        ---@param end_ integer|nil
        ---@return string[]
        lines = function(_, buffer, start, end_)
            local height = buffer.height
            xassert {
                start = {
                    start,
                    {
                        'nil',
                        {
                            'integer',
                            ['>'] = 0,
                            ['<'] = height,
                        },
                    },
                },
                end_ = {
                    end_,
                    {
                        'nil',
                        {
                            'integer',
                            ['>'] = 0,
                            ['<'] = height,
                        },
                    },
                },
            }

            return vim.api.nvim_buf_get_lines(buffer.id, start or 0, end_ and (end_ + 1) or -1, true)
        end,

        ---@param buffer buffer
        ---@param reason string|nil
        confirm_saved = function(_, buffer, reason)
            xassert {
                reason = {
                    reason,
                    {
                        'nil',
                        { 'string', ['>'] = 0 },
                    },
                },
            }

            if buffer.is_modified then
                local message = reason and 'Save changes to "%q" before %s?' or 'Save changes to "%q"?'
                local choice = ide.tui.confirm(string.format(message, ide.fs.base_name(buffer.file_path), reason))

                if choice == nil then -- Cancel
                    return false
                end

                if choice then -- Yes
                    vim.api.nvim_buf_call(buffer.id, vim.cmd.write)
                end
            end

            return true
        end,

        ---@param buffer buffer
        ---@param opts remove_buffer_options|nil
        remove = function(_, buffer, opts)
            opts = table.merge(opts, { force = false })
            xassert {
                opts = {
                    opts,
                    {
                        force = { 'boolean' },
                    },
                },
            }

            local should_remove = not buffer.is_loaded or opts.force or buffer.confirm_saved 'closing'
            if not should_remove then
                return
            end

            for _, window in ipairs(buffer.windows or {}) do
                if window.is_pinned_to_buffer then
                    window.close()
                else
                    window.display_alternate_buffer()
                end
            end

            pcall(vim.cmd.bdelete, { args = { buffer.id }, bang = true })
        end,

        ---@param t buf
        ---@param buffer buffer
        ---@param opts remove_buffer_options|nil
        remove_others = function(t, buffer, opts)
            opts = table.merge(opts, { force = false })
            xassert {
                opts = {
                    opts,
                    {
                        force = { 'boolean' },
                    },
                },
            }

            for _, other_buffer in pairs(t) do
                if other_buffer.id ~= buffer.id and other_buffer.is_listed and other_buffer.is_normal then
                    other_buffer.remove(opts)
                end
            end
        end,

        ---@param buffer buffer
        ---@param next_or_prev boolean # whether to jump to the next or previous diagnostic
        ---@param severity vim.diagnostic.Severity|nil "ERROR"|"WARN"|"INFO"|"HINT"|nil # the severity
        next_diagnostic = function(_, buffer, next_or_prev, severity)
            xassert {
                next_or_prev = { next_or_prev, 'boolean' },
                severity = {
                    severity,
                    {
                        'nil',
                        { 'string', ['*'] = { 'ERROR', 'WARN', 'INFO', 'HINT' } },
                    },
                },
            }

            if not buffer.is_normal then
                return
            end

            local go = next_or_prev and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
            local sev = severity and vim.diagnostic.severity[severity] or nil
            go { severity = sev }
        end,

        ---@param buffer buffer
        ---@param sources string[]|string|nil
        clear_diagnostics = function(_, buffer, sources)
            xassert {
                sources = {
                    sources,
                    {
                        'nil',
                        {
                            'string',
                            ['>'] = 0,
                        },
                        {
                            'list',
                            ['>'] = 0,
                            ['*'] = 'string',
                        },
                    },
                },
            }

            if not sources then
                vim.diagnostic.reset(nil, buffer.id)
                return
            end

            local ns = vim.diagnostic.get_namespaces()

            for _, source in ipairs(table.to_list(sources)) do
                for id, n in pairs(ns) do
                    if n.name == source or string.starts_with(n.name, 'vim.lsp.' .. source) then
                        vim.diagnostic.reset(id, buffer.id)
                    end
                end
            end
        end,

        ---@param buffer buffer
        format = function(_, buffer)
            assert(buffer.is_normal, 'buffer is not a normal buffer')

            if not buffer.check_changed 'format' then
                return
            end

            local plugins = ide.plugin.formatter_plugins

            if #plugins == 0 then
                ide.tui.warn(
                    string.format('No formatter plugins found for buffer "%s"', buffer.file_path),
                    { prefix_icon = require('icons').UI.Format }
                )

                return
            end

            local completed = ide.sched.monitor_task('formatting', { buffer = buffer })

            table.list_iterate(plugins, function(formatter)
                formatter.run(buffer, function(result)
                    completed()

                    if type(result) == 'string' then
                        ide.tui.warn(
                            string.format('Failed to format buffer: %s', result),
                            { prefix_icon = require('icons').UI.Format }
                        )
                    end
                end)
            end)
        end,

        ---@param buffer buffer
        lint = function(_, buffer)
            assert(buffer.is_normal, 'buffer is not a normal buffer')

            if not buffer.check_changed 'lint' then
                return
            end

            local plugins = ide.plugin.linter_plugins

            if #plugins == 0 then
                ide.tui.warn(
                    string.format('No linter plugins found for buffer "%s"', buffer.file_path),
                    { prefix_icon = require('icons').UI.Lint }
                )

                return
            end

            local completed = ide.sched.monitor_task('linting', { buffer = buffer })

            table.list_iterate(plugins, function(linter)
                linter.run(buffer, function(result)
                    completed()

                    if type(result) == 'string' then
                        ide.tui.warn(
                            string.format('Failed to lint buffer: %s', result),
                            { prefix_icon = require('icons').UI.Lint }
                        )
                    end
                end)
            end)
        end,
    },
    properties = {
        current = {
            ---@param t buf
            ---@return buffer
            get = function(t)
                return t[vim.api.nvim_get_current_buf()]
            end,
        },
        alternate = {
            ---@param t buf
            ---@return buffer|nil
            get = function(t)
                local buffer = t[vim.fn.bufnr '#']
                if buffer and buffer.is_listed then
                    return buffer
                end

                return nil
            end,
        },
        auto_formatting_enabled = {
            ---@return boolean
            get = function()
                return auto_formatting_toggle and auto_formatting_toggle.get() or false
            end,
        },
        auto_linting_enabled = {
            ---@return boolean
            get = function()
                return auto_linting_toggle and auto_linting_toggle.get() or false
            end,
        },
    },
    functions = {
        ---@param t buf
        ---@param opts create_buffer_options|nil
        ---@return buffer
        new = function(t, opts)
            opts = table.merge(opts, { listed = true, scratch = false })

            xassert {
                opts = {
                    opts,
                    {
                        listed = { 'boolean' },
                        scratch = { 'boolean' },
                    },
                },
            }

            return t[vim.api.nvim_create_buf(opts.listed, opts.scratch)]
        end,
        ---@param t buf
        ---@param file_path string
        load = function(t, file_path)
            xassert {
                file_path = { file_path, { 'string', ['>'] = 0 } },
            }

            if not ide.fs.file_exists(file_path) then
                return nil
            end

            local buffer = t[vim.fn.bufadd(file_path)]
            if buffer then
                vim.fn.bufload(buffer.id)
            end

            return buffer
        end,
    },
}

ide.plugin.on_formatter_registered(function()
    if auto_formatting_toggle then
        return
    end

    ide.sched.subscribe_event({ 'BufWritePre' }, function(args)
        local buffer = M[args.buf]
        if buffer and buffer.is_normal and buffer.auto_formatting_enabled then
            buffer.format()
        end
    end)

    auto_formatting_toggle = ide.config.register_toggle('auto_formatting_enabled', function(enabled, buffer)
        if buffer and enabled then
            buffer.format()
        end
    end, {
        icon = icons.UI.Format,
        desc = 'Auto-formatting',
        scope = { 'buffer', 'global' },
    })
end)

ide.plugin.on_linter_registered(function()
    if auto_linting_toggle then
        return
    end

    ide.sched.subscribe_event({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, function(args)
        local buffer = M[args.buf]
        if buffer and buffer.is_normal and buffer.auto_linting_enabled then
            buffer.lint()
        end
    end)

    auto_linting_toggle = ide.config.register_toggle('auto_linting_enabled', function(enabled, buffer)
        if buffer and enabled then
            buffer.lint()
        elseif buffer then
            ---@type string[]
            local linters = {}
            for _, tool in ipairs(buffer.tools) do
                if tool.type == 'linter' then
                    table.insert(linters, tool.name)
                end
            end

            if #linters > 0 then
                buffer.clear_diagnostics(linters)
            end
        end
    end, {
        icon = icons.UI.Lint,
        desc = 'Auto-linting',
        scope = { 'buffer', 'global' },
    })
end)

return M

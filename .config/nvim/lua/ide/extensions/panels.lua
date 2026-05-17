-- Panels Extension: IDE status, LSP, Git, and Extensions panels.
-- Provides :IDEStatus, :IDELsp, :IDEGit, :IDEExtensions commands
-- and corresponding actions for command palette discovery.

local Extension = require 'ide.Extension'

local Panels = Class('Panels', Extension)

function Panels:init()
    Extension.init(self, 'Panels')
end

function Panels:_show_status()
    IDE.toolkit.InfoPanel.ide_status():show()
end

function Panels:_show_lsp()
    local buf = IDE.buffers:current()
    local clients = buf:lsp_clients()
    local sections = {}
    for _, client in ipairs(clients) do
        local items = {
            { label = 'Status', value = 'active', hl = 'DiagnosticOk' },
            { label = 'ID', value = tostring(client.id) },
        }
        if client.config and client.config.root_dir then
            items[#items + 1] = { label = 'Root', value = client.config.root_dir }
        end
        sections[#sections + 1] = { heading = '  ' .. client.name, items = items }
    end
    if #sections == 0 then
        sections[1] = { heading = '  LSP', items = { { label = 'No clients attached', value = '', hl = 'Comment' } } }
    end
    IDE.toolkit.InfoPanel({ title = '  LSP Status', sections = sections }):show()
end

function Panels:_show_git()
    local branch = IDE.git:branch() or 'not a repo'
    local root = IDE.git:root() or '-'
    local commits = IDE.git:log({ count = 5 })
    local commit_items = {}
    for _, c in ipairs(commits) do
        commit_items[#commit_items + 1] = { label = c.hash, value = c.subject, hl = 'String' }
    end

    local status_items = {}
    local cwd = IDE.git:root()
    if cwd then
        local result = IDE.shell:run_sync('git', { 'status', '--porcelain', '-u' }, { cwd = cwd, timeout = 3000 })
        if result.code == 0 and result.stdout ~= '' then
            local status_icons = {
                M = { icon = '~', hl = 'DiagnosticWarn' },
                A = { icon = '+', hl = 'DiagnosticOk' },
                D = { icon = '-', hl = 'DiagnosticError' },
                R = { icon = '→', hl = 'DiagnosticInfo' },
                ['?'] = { icon = '?', hl = 'Comment' },
                U = { icon = '!', hl = 'DiagnosticError' },
            }
            for line in result.stdout:gmatch('[^\n]+') do
                local index = line:sub(1, 1)
                local work = line:sub(2, 2)
                local file = vim.trim(line:sub(4))
                local code = work ~= ' ' and work or index
                local info = status_icons[code] or { icon = code, hl = 'Comment' }
                local staged = index ~= ' ' and index ~= '?' and 'staged' or ''
                status_items[#status_items + 1] = {
                    label = info.icon .. ' ' .. file,
                    value = staged,
                    hl = info.hl,
                }
            end
        end
    end

    local diff_items = {}
    if cwd then
        local stat = IDE.shell:run_sync('git', { 'diff', '--stat', '--no-color', 'HEAD' }, { cwd = cwd, timeout = 3000 })
        if stat.code == 0 and stat.stdout ~= '' then
            local lines = vim.split(stat.stdout, '\n')
            local summary = lines[#lines] or lines[#lines - 1] or ''
            if summary:match('%d+ file') then
                diff_items[#diff_items + 1] = { label = 'Changes', value = vim.trim(summary) }
            end
        end
    end

    local sections = {
        { heading = '  Repository', items = {
            { label = 'Branch', value = branch, hl = 'Special' },
            { label = 'Root', value = root },
        }},
    }
    if #diff_items > 0 then
        sections[#sections + 1] = { heading = '  Summary', items = diff_items }
    end
    if #status_items > 0 then
        sections[#sections + 1] = { heading = '  Changed Files (' .. #status_items .. ')', items = status_items }
    end
    sections[#sections + 1] = { heading = '  Recent Commits', items = commit_items }

    IDE.toolkit.InfoPanel({ title = '  Git', sections = sections }):show()
end

function Panels:_show_extensions()
    local SelectPicker = require 'ide.toolkit.SelectPicker'
    local exts = IDE:extensions()
    table.sort(exts, function(a, b) return a:name() < b:name() end)

    local items = {}
    local errored_count = 0
    for _, ext in ipairs(exts) do
        local status = ext:is_errored() and '✗' or (ext:is_enabled() and '●' or '○')
        local status_hl = ext:is_errored() and 'DiagnosticError' or nil
        local cmds = ext._commands and #ext._commands or 0
        local keys = ext._keymaps and #ext._keymaps or 0
        local info = ''
        if ext:is_errored() then
            info = 'ERROR'
            errored_count = errored_count + 1
        elseif cmds > 0 or keys > 0 then
            local parts = {}
            if cmds > 0 then parts[#parts + 1] = cmds .. ' cmds' end
            if keys > 0 then parts[#parts + 1] = keys .. ' keys' end
            info = table.concat(parts, ', ')
        end

        items[#items + 1] = {
            text = status .. '  ' .. ext:name(),
            hint = info,
            hl = status_hl,
            value = ext,
        }
    end

    local title_suffix = errored_count > 0 and (' — ' .. errored_count .. ' errors') or ''
    SelectPicker({
        title = 'Extensions (' .. #exts .. ')' .. title_suffix,
        items = items,
        on_select = function(item)
            local ext = item.value
            local st = ext:is_errored() and 'ERRORED' or (ext:is_enabled() and 'Enabled' or 'Disabled')
            local msg = ext:name() .. '\n'
                .. 'Status: ' .. st .. '\n'
                .. 'Commands: ' .. (ext._commands and #ext._commands or 0) .. '\n'
                .. 'Keymaps: ' .. (ext._keymaps and #ext._keymaps or 0) .. '\n'
                .. 'Hooks: ' .. (ext._hooks and #ext._hooks or 0)
            if ext:is_errored() then
                msg = msg .. '\nError: ' .. (ext:error() or 'unknown')
            end
            IDE.ui:info(msg, { title = ext:name() })
        end,
    }):show()
end

function Panels:on_register(ctx)
    local ext = self

    -- Register actions for command palette discovery
    ctx:action('view.ideStatus', 'IDE Status', function() ext:_show_status() end)
    ctx:action('view.lspStatus', 'LSP Status', function() ext:_show_lsp() end)
    ctx:action('view.gitStatus', 'Git Status', function() ext:_show_git() end)
    ctx:action('view.extensions', 'Extensions', function() ext:_show_extensions() end)

    -- Commands (call through actions)
    ctx:command('IDEStatus', function() IDE.actions:execute('view.ideStatus') end, { desc = 'Show IDE status panel' })
    ctx:command('IDELsp', function() IDE.actions:execute('view.lspStatus') end, { desc = 'Show LSP status' })
    ctx:command('IDEGit', function() IDE.actions:execute('view.gitStatus') end, { desc = 'Show git status' })
    ctx:command('IDEExtensions', function() IDE.actions:execute('view.extensions') end, { desc = 'List IDE extensions' })
end

return Panels

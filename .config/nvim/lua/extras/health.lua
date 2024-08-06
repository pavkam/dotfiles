local keys = require 'core.keys'
local markdown = require 'extras.markdown'
local sessions = require 'core.sessions'

local M = {}

---@class (exact) extras.health.ShowOpts
---@field public height number|nil
---@field public width number|nil

--- Shows a window with the given content
---@param content string[] # the content to show
---@param opts extras.health.ShowOpts|nil # the options for the window
local function show_content(content, opts)
    opts = opts or {}

    local height = math.floor(vim.o.lines * (opts.height or 0.5))
    local width = math.floor(vim.o.columns * (opts.width or 0.5))

    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_open_win(buffer, true, {
        relative = 'editor',
        border = vim.g.border_style,
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = 'minimal',
    })

    ---@type string[]
    local lines = {}
    for _, line in ipairs(content) do
        for _, sub_line in ipairs(vim.split(line, '\n')) do
            table.insert(lines, sub_line)
        end
    end

    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, lines)

    vim.bo[buffer].modifiable = false
    vim.bo[buffer].modified = false
    vim.bo[buffer].bufhidden = 'wipe'
    vim.bo[buffer].filetype = 'markdown'
    vim.bo[buffer].buftype = 'nofile'
    vim.bo[buffer].readonly = true
    vim.wo[window].spell = false

    keys.map('n', 'q', '<cmd>close<cr>', { buffer = buffer, nowait = true, desc = 'Close window' })
    keys.map('n', '<Esc>', '<cmd>close<cr>', { buffer = buffer, nowait = true, desc = 'Close window' })

    vim.api.nvim_create_autocmd('BufLeave', {
        desc = 'Close info window when leaving buffer',
        buffer = buffer,
        once = true,
        nested = true,
        callback = function()
            if vim.api.nvim_win_is_valid(window) then
                vim.api.nvim_win_close(window, true)
            end
        end,
    })
end

--- Shows the health of the current buffer
---@param buffer integer|nil # the buffer to show the health for, defaults to the current buffer
local function show_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local lsp = require 'project.lsp'
    local settings = require 'core.settings'
    local project = require 'project'
    local debugging = require 'debugging'
    local progress = require 'ui.progress'

    local current_session = sessions.current()
    local md = markdown.from_value

    local buffer_info = md {
        id = buffer,
        windows = vim.fn.win_findbuf(buffer),
        name = vim.api.nvim_buf_get_name(buffer),
        file_type = vim.api.nvim_get_option_value('filetype', { buf = buffer }),
        buf_type = vim.api.nvim_get_option_value('buftype', { buf = buffer }),
        modifiable = vim.api.nvim_get_option_value('modifiable', { buf = buffer }),
        modified = vim.api.nvim_get_option_value('modified', { buf = buffer }),
        read_only = vim.api.nvim_get_option_value('readonly', { buf = buffer }),
        spell_files = vim.api.nvim_get_option_value('spellfile', { buf = buffer }),
    }

    local progress_info = md(progress.snapshot())

    local session_info = current_session
        and md {
            name = current_session,
            files = { sessions.files(current_session) },
        }

    local project_info = md {
        type = project.type(buffer) or 'unsupported',
        root = project.root(buffer),
        roots = project.roots(buffer),
        lsp_roots = lsp.roots(buffer),
        JS = vim.tbl_contains(project.js_types, project.type(buffer)) and {
            eslint_config = project.get_eslint_config_path(buffer),
            jest = project.get_js_bin_path(buffer, 'jest'),
            eslint = project.get_js_bin_path(buffer, 'eslint'),
            prettier = project.get_js_bin_path(buffer, 'prettier'),
            vitest = project.get_js_bin_path(buffer, 'vitest'),
        } or nil,
        GO = project.type(buffer) == 'go' and {
            golangci = project.get_golangci_config(buffer),
        } or nil,
    }

    local settings_info = md(settings.snapshot(buffer))

    local dap_info = md(package.loaded['dap'] and debugging.configurations(buffer))

    local lsp_info = md {
        LSP = vim.inflate_list(
            function(client)
                return client.name
            end,
            vim.iter(vim.lsp.get_clients { bufnr = buffer })
                :map(function(client)
                    return {
                        id = client.id,
                        name = client.name,
                        root = client.root_dir,
                        client_capabilities = client.capabilities,
                        server_capabilities = client.server_capabilities,
                        dynamic_capabilities = client.dynamic_capabilities,
                        requests = client.requests,
                    }
                end)
                :totable()
        ),
    }

    local info = '# Buffer\n'
        .. buffer_info
        .. '\n\n'
        .. '# Session\n'
        .. (session_info or 'No session')
        .. '\n\n'
        .. '# Project\n'
        .. project_info
        .. '\n\n'
        .. '# Settings\n'
        .. settings_info
        .. '\n\n'
        .. '# Progress\n'
        .. progress_info
        .. '\n\n'
        .. '# DAP\n'
        .. (dap_info or 'No DAP')
        .. '\n\n'
        .. '# LSP\n'
        .. lsp_info

    show_content(vim.fn.split(info, '\n'))
end

function M.check()
    vim.health.start 'Personal configuration'

    --- Checks if a tool is installed
    ---@param tool string # the tool to check
    ---@param important boolean # whether the tool is important
    local function check_executable(tool, important)
        assert(type(tool) == 'string')
        assert(type(important) == 'boolean')

        local installed = vim.fn.executable(tool) == 1
        if not installed then
            local fn = important and vim.health.error or vim.health.warn
            fn(string.format('%s is not installed', tool))
        else
            vim.health.ok(string.format('%s is installed at "%s"', tool, vim.fn.exepath(tool)))
        end
    end

    local important_tools = { 'git', 'rg', 'fd', 'fzf', 'node', 'npm', 'yarn' }
    for _, tool in ipairs(important_tools) do
        check_executable(tool, true)
    end

    local optional_tools = { 'lazygit' }
    for _, tool in ipairs(optional_tools) do
        check_executable(tool, false)
    end

    vim.health._complete()
end

--- Registers stack trace highlights for a buffer
---@param buffer integer|nil # the buffer to register the highlights for, defaults to the current buffer
function M.register_stack_trace_highlights(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_call(buffer, function()
            vim.fn.matchadd('WarningMsg', [[[^/]\+\.lua:\d\+\ze:]])
        end)
    end
end

-- Show buffer information
require('core.commands').register_command('Debug', function()
    show_for_buffer()
end, { desc = 'Show buffer information', nargs = 0 })

return M

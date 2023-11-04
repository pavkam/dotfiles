local utils = require 'utils'

---@class utils.health.ShowOpts
---@field public height number|nil
---@field public width number|nil

---@class utils.health
local M = {}

--- Shows a window with the given content
---@param content string[] # the content to show
---@param opts? utils.health.ShowOpts # the options for the window
function M.show_content(content, opts)
    opts = opts or {}

    local height = math.floor(vim.o.lines * (opts.height or 0.5))
    local width = math.floor(vim.o.columns * (opts.width or 0.5))

    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_open_win(buffer, true, {
        relative = 'editor',
        border = 'rounded',
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = 'minimal',
    })

    vim.api.nvim_buf_set_lines(buffer, 0, -1, true, content)

    vim.bo[buffer].modifiable = false
    vim.bo[buffer].modified = false
    vim.bo[buffer].bufhidden = 'wipe'
    vim.bo[buffer].filetype = 'markdown'
    vim.bo[buffer].buftype = 'nofile'
    vim.bo[buffer].readonly = true
    vim.wo[window].spell = false

    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buffer, nowait = true, desc = 'Close window' })
    vim.keymap.set('n', '<Esc>', '<cmd>close<cr>', { buffer = buffer, nowait = true, desc = 'Close window' })

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
function M.show_for_buffer(buffer)
    buffer = buffer or vim.api.nvim_get_current_buf()

    local lsp = require 'utils.lsp'
    local settings = require 'utils.settings'
    local project = require 'utils.project'

    local content = {}

    ---@param name string
    ---@param items string[]|table<string, any>
    local function list(name, items)
        if vim.tbl_isempty(items) then
            return
        end

        table.insert(content, '# ' .. name)

        if vim.tbl_islist(items) then
            for _, item in ipairs(items) do
                item = string.gsub(utils.stringify(item) or '', '\n', ' ')
                table.insert(content, string.format(' - `%s`', item))
            end
        else
            for k, v in pairs(items) do
                v = string.gsub(utils.stringify(v) or '', '\n', ' ')
                table.insert(content, string.format(' - **%s** = `%s`', k, v))
            end
        end

        table.insert(content, '')
    end

    local buffer_details = {
        id = buffer,
        name = vim.api.nvim_buf_get_name(buffer),
        filetype = vim.api.nvim_buf_get_option(buffer, 'filetype'),
        buftype = vim.api.nvim_buf_get_option(buffer, 'buftype'),
        modifiable = vim.api.nvim_buf_get_option(buffer, 'modifiable'),
        modified = vim.api.nvim_buf_get_option(buffer, 'modified'),
        readonly = vim.api.nvim_buf_get_option(buffer, 'readonly'),
    }
    list('Buffer', buffer_details)

    local project_details = {
        type = project.type(buffer) or 'unsupported',
        root = project.root(buffer),
        roots = project.roots(buffer),
        lsp_roots = lsp.roots(buffer),
    }

    list('Project', project_details)

    for name, tb in pairs(settings.snapshot_for_buffer(buffer)) do
        list(string.format('Settings (%s)', name), tb)
    end

    for _, cfg in ipairs(project.dap_configurations(buffer)) do
        list(string.format('DAP (%s)', cfg.name), cfg)
    end

    M.show_content(content)
end

return M
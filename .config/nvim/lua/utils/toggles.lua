local utils = require 'utils'
local settings = require 'utils.settings'

---@class utils.toggles
local M = {}

--- Toggles a transient option for a buffer
---@param option string # the name of the option
---@param opts? { buffer?: integer, default?: boolean, description?: string } # optional modifiers
---@return boolean # whether the option is enabled
local function toggle(option, opts)
    assert(type(option) == 'string' and option ~= '')

    opts = opts or {}
    opts.description = opts.description or option
    assert(type(opts.description) == 'string' and opts.description ~= '')

    local enabled = settings.get(option, { buffer = opts.buffer, default = opts.default })

    if opts.buffer ~= nil then
        local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.buffer), ':t')
        utils.info(string.format('Turning **%s** %s for *%s*.', enabled and 'off' or 'on', opts.description, file_name))
    else
        utils.info(string.format('Turning **%s** %s *globally*.', enabled and 'off' or 'on', opts.description))
    end

    settings.set(option, not enabled, { buffer = opts.buffer })

    return not enabled
end

--- Toggles diagnostics on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_diagnostics(opts)
    opts = opts or {}

    local enabled = toggle('diagnostics_enabled', { buffer = opts.buffer, description = 'diagnostics', default = true })
    if not enabled then
        vim.diagnostic.disable(opts.buffer)
    else
        vim.diagnostic.enable(opts.buffer)
    end
end

--- Toggles treesitter on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_treesitter(opts)
    opts = opts or {}
    opts.buffer = opts.buffer or vim.api.nvim_get_current_buf()

    local enabled = toggle('treesitter_enabled', { buffer = opts.buffer, description = 'treesitter', default = true })

    if not enabled then
        vim.treesitter.stop(opts.buffer)
    else
        vim.treesitter.start(opts.buffer)
    end
end

--- Toggles ignoring of hidden files on or off
function M.toggle_ignore_hidden_files()
    local val = toggle('ignore_hidden_files', { description = 'hiding ignored files', default = true })

    -- Update Neo-Tree state
    if package.loaded['neo-tree'] then
        local state = require('neo-tree.sources.manager').get_state 'filesystem'
        state.filtered_items.visible = val
    end
end

--- Toggles auto-autoformatting on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_auto_formatting(opts)
    local format = require 'utils.format'

    opts = opts or {}
    opts.buffer = opts.buffer == nil and nil or opts.buffer or vim.api.nvim_get_current_buf()

    local enabled = toggle('auto_formatting_enabled', { buffer = opts.buffer, description = 'auto-linting', default = true })

    local buffers = opts.buffer ~= nil and { opts.buffer } or utils.get_listed_buffers()

    if enabled then
        -- re-format
        for _, buffer in ipairs(buffers) do
            if settings.buf[buffer].auto_formatting_enabled and settings.global.auto_formatting_enabled then
                format.apply(buffer)
            end
        end
    end
end

--- Toggles auto-linting on or off
---@param opts? { buffer?: integer } # optional modifiers
function M.toggle_auto_linting(opts)
    local lint = require 'utils.lint'
    local lsp = require 'utils.lsp'

    opts = opts or {}
    opts.buffer = opts.buffer == nil and nil or opts.buffer or vim.api.nvim_get_current_buf()

    local enabled = toggle('auto_linting_enabled', { buffer = opts.buffer, description = 'auto-linting', default = true })

    local buffers = opts.buffer ~= nil and { opts.buffer } or utils.get_listed_buffers()

    if not enabled then
        -- clear diagnostics
        for _, buffer in ipairs(buffers) do
            lsp.clear_diagnostics(lint.active_names_for_buffer(buffer), buffer)
        end
    else
        -- re-lint
        for _, buffer in ipairs(buffers) do
            if settings.buf[buffer].auto_linting_enabled and settings.global.auto_linting_enabled then
                lint.apply(buffer)
            end
        end
    end
end

return M

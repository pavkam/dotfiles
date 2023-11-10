return {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    build = ':Copilot auth',
    opts = {
        suggestion = {
            enabled = true,
            auto_trigger = true,
            debounce = 150,
        },
        panel = { enabled = false },
    },
    config = function(_, opts)
        local utils = require 'utils'

        -- create new hl group for copilot annotations
        ---@diagnostic disable-next-line: undefined-field
        local comment_hl = vim.api.nvim_get_hl_by_name('Comment', true)
        local new_hl = vim.tbl_extend('force', {}, comment_hl, { fg = '#7287fd' })

        vim.api.nvim_set_hl(0, 'CopilotAnnotation', new_hl)
        vim.api.nvim_set_hl(0, 'CopilotSuggestion', new_hl)

        local copilot = require 'copilot'
        local copilot_api = require 'copilot.api'

        copilot.setup(opts)

        -- status updates for Copilot
        local curr_status
        copilot_api.register_status_notification_handler(function()
            if copilot_api.status.data.status ~= curr_status then
                curr_status = copilot_api.status.data.status
                utils.trigger_status_update_event()
            end
        end)
    end,
}

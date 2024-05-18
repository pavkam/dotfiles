return {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    build = ':Copilot auth',
    opts = {
        suggestion = {
            enabled = true,
            auto_trigger = true,
            debounce = 75,
        },
        panel = { enabled = false },
    },
    config = function(_, opts)
        local utils = require 'core.utils'
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

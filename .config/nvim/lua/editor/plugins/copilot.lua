return {
    {
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
            local copilot = require 'copilot'
            local copilot_api = require 'copilot.api'

            copilot.setup(opts)

            -- status updates for Copilot
            local curr_status
            copilot_api.register_status_notification_handler(function()
                if copilot_api.status.data.status ~= curr_status then
                    curr_status = copilot_api.status.data.status
                    require('core.events').trigger_status_update_event()
                end
            end)
        end,
    },
    {
        'CopilotC-Nvim/CopilotChat.nvim',
        branch = 'canary',
        cmd = {
            'CopilotChat',
            'CopilotChatOpen',
            'CopilotChatClose',
            'CopilotChatToggle',
            'CopilotChatStop',
            'CopilotChatReset',
            'CopilotChatSave',
            'CopilotChatLoad',
            'CopilotChatDebugInfo',
            'CopilotChatExplain',
            'CopilotChatReview',
            'CopilotChatFix',
            'CopilotChatOptimize',
            'CopilotChatDocs',
            'CopilotChatTests',
            'CopilotChatFixDiagnostic',
            'CopilotChatCommit',
            'CopilotChatCommitStaged',
        },
        dependencies = {
            'zbirenbaum/copilot.lua',
            'nvim-lua/plenary.nvim',
        },
        opts = {},
    },
}

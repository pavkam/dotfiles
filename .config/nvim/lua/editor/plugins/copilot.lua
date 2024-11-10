return {
    {
        'zbirenbaum/copilot.lua',
        cond = not vim.headless,
        cmd = 'Copilot',
        build = ':Copilot auth',
        lazy = false, -- TODO: temporary hack
        opts = {
            suggestion = {
                enabled = true,
                auto_trigger = true,
                debounce = 75,
            },
            panel = { enabled = false },
        },
        config = function(_, opts)
            -- TODO: "unexpectedly started multiple copilot instances". Probably due to CopilotChat messing around
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
        -- TODO: add keymap for invoking some of these commands
        -- TODO: make the buffer the default context
        -- TODO: make sure the c-y works as expected (updates the buffer)
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
        build = 'make tiktoken',
        opts = {
            auto_insert_mode = true,
            window = {
                layout = 'float',
                width = 0.5,
                height = 0.5,
                border = vim.g.border_style,
            },
            mappings = {
                close = {
                    normal = 'q',
                    insert = '<C-q>',
                },
                reset = {
                    normal = '<C-c>',
                    insert = '<C-c>',
                },
                submit_prompt = {
                    normal = '<CR>',
                    insert = '<C-CR>',
                },
            },
        },
        config = function(_, opts)
            require('CopilotChat').setup(opts)
            require('CopilotChat.integrations.cmp').setup()
        end,
    },
}

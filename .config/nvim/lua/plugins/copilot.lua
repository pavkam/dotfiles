---@module 'CopilotChat'

return {
    {
        'zbirenbaum/copilot.lua',
        cond = not ide.process.is_headless,
        cmd = 'Copilot',
        build = ':Copilot auth',
        ---@type copilot_config
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

            copilot.setup(opts)

            -- status updates for Copilot
            local copilot_api = require 'copilot.api'

            local curr_status
            copilot_api.register_status_notification_handler(function()
                if copilot_api.status.data.status ~= curr_status then
                    curr_status = copilot_api.status.data.status
                    require('events').trigger_status_update_event()
                end
            end)

            ide.theme.register_highlight_groups {
                CopilotAnnotation = '@string.regexp',
                CopilotSuggestion = '@string.regexp',
            }
        end,
    },
    {
        'CopilotC-Nvim/CopilotChat.nvim',
        cmd = {
            'CopilotChat',
            'CopilotChatStop',
        },
        dependencies = {
            'zbirenbaum/copilot.lua',
            'nvim-lua/plenary.nvim',
        },
        build = 'make tiktoken',
        ---@type CopilotChat.config
        opts = {
            context = '#buffers',
            chat_autocomplete = true,
            auto_insert_mode = true,
            auto_follow_cursor = true,
            model = 'claude-3.5-sonnet',
            window = {
                layout = 'vertical',
                width = 0.3,
                border = vim.g.border_style,
                title = require('icons').UI.AI .. ' Copilot',
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
    },
}

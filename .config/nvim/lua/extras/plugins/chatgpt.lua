local utils = require 'core.utils'
local icons = require 'ui.icons'

return {
    'jackMort/ChatGPT.nvim',
    dependencies = {
        'MunifTanjim/nui.nvim',
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cmd = { 'ChatGPT', 'ChatGPTActAs', 'ChatGPTEditWithInstructions', 'ChatGPTRun' },
    keys = {
        {
            '<leader>x',
            function()
                utils.run_with_visual_selection(nil, function(restore)
                    require('ui.select').command {
                        {
                            name = 'Edit code',
                            desc = 'Complete code, fix bugs, optimize code, etc.',
                            command = function()
                                restore 'ChatGPTEditWithInstructions'
                            end,
                        },
                        {
                            name = 'Correct grammar',
                            desc = 'Correct grammar of a sentence.',
                            command = function()
                                restore 'ChatGPTRun correct_grammar'
                            end,
                        },
                        {
                            name = 'Complete code',
                            desc = 'Complete code and fix bugs.',
                            command = function()
                                restore 'ChatGPTRun complete_code'
                            end,
                        },
                        {
                            name = 'Document code',
                            desc = 'Document code and explain code.',
                            command = function()
                                restore 'ChatGPTRun document'
                            end,
                        },
                        {
                            name = 'Add unit tests',
                            desc = 'Add unit tests to code.',
                            command = function()
                                restore 'ChatGPTRun add_tests'
                            end,
                        },
                        {
                            name = 'Optimize code',
                            desc = 'Optimize code and fix bugs.',
                            command = function()
                                restore 'ChatGPTRun optimize_code'
                            end,
                        },
                        {
                            name = 'Fix bugs in code',
                            desc = 'Fix bugs in code and optimize code.',
                            command = function()
                                restore 'ChatGPTRun fix_bugs'
                            end,
                        },
                        {
                            name = 'Explain code',
                            command = function()
                                restore 'ChatGPTRun explain_code'
                            end,
                        },
                    }
                end)
            end,
            mode = 'v',
            desc = icons.UI.AI .. 'Edit with AI',
        },
    },
    opts = {
        api_key_cmd = 'cat ' .. vim.fs.normalize '~/.config/.oai',
        yank_register = '*',
        edit_with_instructions = {
            keymaps = {
                close = '<C-q>',
                accept = '<C-a>',
                toggle_diff = '<C-d>',
                toggle_settings = '<C-o>',
                cycle_windows = '<Tab>',
                use_output_as_input = '<C-i>',
            },
        },
        popup_input = {
            prompt = icons.TUI.PromptPrefix .. ' ',
        },
        popup_window = {
            border = {
                text = {
                    top = ' ' .. icons.UI.AI .. 'AI ',
                },
            },
        },
        chat = {
            loading_text = 'Loading, please wait ...',
            question_sign = icons.TUI.PromptPrefix,
            answer_sign = icons.TUI.LineEnd,
            keymaps = {
                close = '<C-q>',
                yank_last = '<C-y>',
                yank_last_code = '<C-k>',
                scroll_up = { '<C-u>', '<PageUp>' },
                scroll_down = { '<C-d>', '<PageDown>' },
                new_session = '<C-n>',
                cycle_windows = '<Tab>',
                cycle_modes = '<C-f>',
                next_message = { '<C-j>', '<Down>' },
                prev_message = { '<C-k>', '<Up>' },
                select_session = '<Space>',
                rename_session = 'r',
                delete_session = 'd',
                draft_message = '<C-d>',
                edit_message = 'e',
                delete_message = 'd',
                toggle_settings = '<C-o>',
                toggle_message_role = '<C-r>',
                toggle_system_role_open = '<C-s>',
                stop_generating = '<C-x>',
            },
        },
        openai_params = {
            model = 'gpt-4-1106-preview',
        },
        openai_edit_params = {
            model = 'gpt-4-1106-preview',
        },
        actions_paths = { vim.fn.stdpath 'config' .. '/chat_gpt_actions.json' },
        show_quickfixes_cmd = 'copen',
    },
    config = function(_, opts)
        require('chatgpt').setup(opts)
    end,
}

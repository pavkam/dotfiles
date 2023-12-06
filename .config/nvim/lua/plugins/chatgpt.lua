local icons = require 'utils.icons'

return {
    'jackMort/ChatGPT.nvim',
    enabled = feature_level(3),
    dependencies = {
        'MunifTanjim/nui.nvim',
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
    },
    cmd = { 'ChatGPT', 'ChatGPTActAs', 'ChatGPTEditWithInstructions', 'ChatGPTRun' },
    keys = {
        { '<leader>xx', '<Cmd>ChatGPT<CR>', mode = 'n', desc = 'Chat' },
        { '<leader>xx', '<Cmd>ChatGPTEditWithInstruction<CR>', mode = 'v', desc = 'Edit code' },
        { '<leader>xg', '<cmd>ChatGPTRun correct_grammar<CR>', desc = 'Correct grammar', mode = 'v' },
        { '<leader>xc', '<cmd>ChatGPTRun complete_code<CR>', desc = 'Complete code', mode = 'v' },
        { '<leader>xd', '<cmd>ChatGPTRun document<CR>', desc = 'Document code', mode = 'v' },
        { '<leader>xt', '<cmd>ChatGPTRun add_tests<CR>', desc = 'Add unit tests', mode = 'v' },
        { '<leader>xo', '<cmd>ChatGPTRun optimize_code<CR>', desc = 'Optimize code', mode = 'v' },
        { '<leader>xf', '<cmd>ChatGPTRun fix_bugs<CR>', desc = 'Fix bugs in code', mode = 'v' },
        { '<leader>xe', '<cmd>ChatGPTRun explain_code<CR>', desc = 'Explain code', mode = 'v' },
        { '<leader>x', '<Nop>', mode = { 'v', 'n' } },
    },
    opts = {
        api_key_cmd = 'cat ' .. vim.fs.normalize '~/.config/.oai',
        yank_register = '*',
        edit_with_instructions = {
            keymaps = {
                close = 'C-q',
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

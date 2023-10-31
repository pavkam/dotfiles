return {
    'numToStr/Comment.nvim',
    dependencies = {
        {
            'JoosepAlviste/nvim-ts-context-commentstring',
            opts = {
                enable_autocmd = false,
            },
        },
    },
    keys = {
        { 'gc', mode = { 'n', 'v' }, desc = 'Toggle line comment' },
        { 'gb', mode = { 'n', 'v' }, desc = 'Toggle block comment' },
    },
    opts = function()
        local ts_comment_string = require 'ts_context_commentstring.integrations.comment_nvim'
        return {
            pre_hook = ts_comment_string.create_pre_hook(),
        }
    end,
}

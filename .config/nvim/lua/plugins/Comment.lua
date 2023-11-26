return {
    'numToStr/Comment.nvim',
    dependencies = {
        {
            'JoosepAlviste/nvim-ts-context-commentstring',
            opts = {
                enable_autocmd = false,
            },
            init = function()
                vim.g.skip_ts_context_commentstring_module = true
            end,
        },
    },
    keys = {
        { 'gc', mode = { 'n', 'v' }, desc = 'Toggle line comment' },
        { 'gb', mode = { 'n', 'v' }, desc = 'Toggle block comment' },
    },
    opts = function()
        -- TODO: fix this
        -- context_commentstring nvim-treesitter module is deprecated, use require('ts_context_commentstring').setup {} and set vim.g.skip_ts_context_commentstring_module = true to speed up loading instead.
        -- This feature will be removed in ts_context_commentstring version in the future
        local ts_comment_string = require 'ts_context_commentstring.integrations.comment_nvim'
        return {
            pre_hook = ts_comment_string.create_pre_hook(),
        }
    end,
}

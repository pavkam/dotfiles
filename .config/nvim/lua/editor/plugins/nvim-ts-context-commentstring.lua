return {
    'JoosepAlviste/nvim-ts-context-commentstring',
    opts = {
        enable_autocmd = false,
    },
    init = function()
        vim.g.skip_ts_context_commentstring_module = true

        vim.schedule(function()
            local get_option = vim.filetype.get_option

            ---@diagnostic disable-next-line: duplicate-set-field
            vim.filetype.get_option = function(filetype, option)
                return option == 'commentstring' and require('ts_context_commentstring.internal').calculate_commentstring() or get_option(filetype, option)
            end
        end)
    end,
}

return {
    "zbirenbaum/copilot.lua",
    config = function(plugin, opts)
         -- create new hl group for copilot annotations
        local comment_hl = vim.api.nvim_get_hl_by_name('Comment', true)
        local new_hl = vim.tbl_extend('force', {}, comment_hl, { fg = '#7287fd' })
        vim.api.nvim_set_hl(0, 'CopilotAnnotation', new_hl)
        vim.api.nvim_set_hl(0, 'CopilotSuggestion', new_hl)

        require("copilot").setup(opts)
    end
}

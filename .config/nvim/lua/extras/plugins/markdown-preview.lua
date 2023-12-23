return {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    build = function()
        vim.fn['mkdp#util#install']()
    end,
    keys = {
        {
            '<leader>p',
            ft = 'markdown',
            '<cmd>MarkdownPreviewToggle<cr>',
            desc = 'Preview markdown',
        },
    },
    config = function()
        vim.cmd [[do FileType]]
    end,
}

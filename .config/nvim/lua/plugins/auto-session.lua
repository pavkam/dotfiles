return {
    -- TODO: maybe use resession? It allows for much more custom stuff than this
    'rmagatti/auto-session',
    cond = feature_level(2),
    keys = {
        {
            '<leader>S',
            function()
                require('auto-session.session-lens').search_session()
            end,
            desc = 'Sessions',
        },
    },
    opts = {
        log_level = 'error',
        auto_session_suppress_dirs = { '~/', '/' },
        auto_session_enable_last_session = false,
        auto_session_root_dir = vim.fn.stdpath 'data' .. '/sessions/',
        auto_session_enabled = true,
        auto_session_create_enabled = true,
        auto_save_enabled = true,
        auto_restore_enabled = true,
        auto_session_use_git_branch = true,
        bypass_session_save_file_types = { 'gitcommit', 'gitrebase', 'svn', 'hgcommit' },
    },
}

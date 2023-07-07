require('lspsaga').setup({
    finder = {
        keys = {
            jump_to = '<Tab>',
            expand_or_jump = '<CR>',
            vsplit = '<S-Right>',
            split = '<S-Down>',
            tabe = 'te',
            tabnew = 'tn',
            quit = { 'q', '<ESC>' },
            close_in_preview = { 'q', '<ESC>' },
        },
    },
    code_action = {
        keys = {
          quit = { 'q', '<ESC>' },
          exec = '<CR>',
        },
    },
    rename = {
        quit = { 'q', '<ESC>' },
        exec = '<CR>',
        mark = 'x',
        confirm = '<CR>',
        in_select = true,
    },
    outline = {
        keys = {
            expand_or_jump = '<CR>',
            quit = { 'q', '<ESC>' },
        },
  },
})

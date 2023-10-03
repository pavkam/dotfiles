vim.cmd('set backspace=indent,eol,start whichwrap+=<,>,[,]')

vim.opt.shortmess:append('I')
vim.opt.formatoptions:append('1')

return {
    opt = {
        shell = '/bin/bash -i',
        grepprg=[[rg\ --vimgrep\ --no-heading\ --smart-case]],
        grepformat='%f:%l:%c:%m,%f:%l:%m',

        title = true,
        visualbell = true,
        showmode = false,
        modeline = false,
        errorbells = false,
        ruler = false,
        showcmd = true,
        wrap = false,
        showbreak = '↳ ',
        nrformats = '',
        clipboard = 'unnamedplus',
        signcolumn = "auto:1-4",
        number = true,
        ttyfast = true,
        termencoding = 'utf-8',
        encoding='utf-8',
        lazyredraw = false,
        laststatus = 2,
        cmdheight = 0,
        wildmenu = true,

        -- file management
        filetype = 'on',
        syntax = 'on',
        fileformats = 'unix,dos,mac',
        autoread = true,
        updatetime = 1000,

        -- tabs
        smartindent = true,
        tabstop = 4,
        softtabstop = 4,
        expandtab = true,
        shiftwidth = 4,
        shiftround = true,
        autoindent = true,
        copyindent = true,
        smarttab = true,

        -- editing
        scrolloff = 4,
        virtualedit = 'onemore',
        mouse = 'a',
        showmatch = true,
        cursorline = true,
        keymodel = 'startsel,stopsel',

        -- search & replace
        hlsearch = false,
        incsearch = true,
        gdefault = true,
        ignorecase = true,
        smartcase = true,

        -- special
        listchars='tab:▸ ,trail:·,extends:#,nbsp:·',
        list = false,

        -- spell
        spell = true,
        spelllang = { 'en_us' },
    },
    g = {
        mapleader = ' ',
        autoformat_enabled = true,
        cmp_enabled = true,
        autopairs_enabled = true,
        diagnostics_mode = 3,
        icons_enabled = true,
        ui_notifications_enabled = true,
        resession_enabled = true,
    }
}

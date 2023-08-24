vim.cmd('set backspace=indent,eol,start whichwrap+=<,>,[,]')
--vim.cmd('runtime mswin.vim')

vim.opt.shortmess:append('I')
vim.opt.formatoptions:append('1')

return {
    opt = {
        title = true,
        visualbell = true,
        showmode = false,
        modeline = false,
        errorbells = false,
        ruler = false,
        showcmd = true,
        wrap = false,
        nrformats = '',
        clipboard = 'unnamedplus',
        number = true,
        ttyfast = true,
        switchbuf = 'useopen',
        termencoding = 'utf-8',
        encoding='utf-8',
        lazyredraw = false,
        laststatus = 2,
        cmdheight = 1,
        wildmenu = true,
        wildignore = "*.swp,*.bak,*.pyc,*.class,*.o,*.out,*.a",

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
        shiftwidth = 4,
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
        history = 1000,
        undolevels = 1000,
        undofile = true,
        undodir = vim.fn.expand('~/.cache/nvim/undodir'),
        backup = false,
        writebackup = false,
        swapfile = false,
        cursorline = false,
        keymodel = 'startsel,stopsel',

        -- search & replace
        hlsearch = true,
        incsearch = true,
        gdefault = true,
        ignorecase = true,
        smartcase = true,

        -- special
        listchars='tab:▸ ,trail:·,extends:#,nbsp:·',
        list = false,
    },
    g = {
        mapleader = ' ',
        autoformat_enabled = true,
        cmp_enabled = true,
        autopairs_enabled = true,
        diagnostics_mode = 3,
        icons_enabled = true,
        ui_notifications_enabled = true,
        resession_enabled = false,
    }
}

local set = vim.opt

-- general
vim.cmd('behave mswin')

set.title = true
set.visualbell = true
set.showmode = false
set.modeline = false
set.errorbells = false
set.ruler = false
set.showcmd = true
set.wrap = false
set.nrformats = ''
set.shortmess:append('I')
set.clipboard = 'unnamedplus'
set.number = true
set.ttyfast = true
set.hidden = true
set.switchbuf = 'useopen'
set.termencoding = 'utf-8'
set.encoding='utf-8'
set.lazyredraw = true
set.laststatus = 2
set.cmdheight = 1
set.wildmenu = true
set.wildignore = "*.swp,*.bak,*.pyc,*.class,*.o,*.out,*.a"

-- file management
set.filetype = 'on'
set.syntax = 'on'
set.fileformats = 'unix,dos,mac'
set.formatoptions:append('1')
set.autoread = true
set.updatetime = 1000

-- tabs
set.smartindent = true
set.tabstop = 4
set.softtabstop = 4
set.shiftwidth = 4
set.expandtab = true
set.shiftwidth = 4
set.shiftround = true
set.autoindent = true
set.copyindent = true
set.smarttab = true

-- editing
vim.cmd('set backspace=indent,eol,start whichwrap+=<,>,[,]')
set.scrolloff = 4
set.virtualedit = 'onemore'
set.mouse = 'a'
set.showmatch = true
set.history = 1000
set.undolevels = 1000
set.undofile = true
set.undodir = vim.fn.expand('~/.cache/nvim/undodir')
set.backup = false
set.writebackup = false
set.swapfile = false
set.cursorline = false
set.keymodel = 'startsel,stopsel'

-- search & replace
set.hlsearch = true
set.incsearch = true
set.gdefault = true
set.ignorecase = true
set.smartcase = true

-- special
set.listchars='tab:▸ ,trail:·,extends:#,nbsp:·'
set.list = false

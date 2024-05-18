local icons = require 'ui.icons'

-- Global options for neovim
local o = vim.opt
local g = vim.g

-- basic
g.mapleader = ' '
g.maplocalleader = ' '
g.markdown_recommended_style = 0

-- utilities
o.shell = '/bin/bash -i'

if vim.fn.executable 'rg' then
    o.grepprg = [[rg --vimgrep --no-heading --smart-case]]
    o.grepformat = '%f:%l:%c:%m,%f:%l:%m'
end

-- terminal
o.ttimeout = true
o.timeoutlen = 300
o.ttimeoutlen = 10
o.errorbells = false
o.visualbell = true
o.title = true
o.clipboard = 'unnamedplus'
o.mouse = 'a'

-- ui
o.showmode = false
o.modeline = false
o.ruler = false
o.showcmd = true
o.wrap = false
o.showbreak = icons.TUI.LineContinuation .. ' '
o.nrformats = ''
o.ttyfast = true
o.termguicolors = true
o.encoding = 'utf-8'
o.lazyredraw = false
o.winblend = 10
o.guicursor =
    [[n-v-c-sm:block-blinkwait500-blinkoff400-blinkon250,i-ci:ver25-blinkwait1000-blinkoff400-blinkon250,v:block-blinkwait500-blinkoff400-blinkon250,r-cr-o:hor20-blinkwait1000-blinkoff400-blinkon250]]

-- menu and cmd-line
o.laststatus = 2
o.cmdheight = 0

o.wildignore:append { '*.o', '*~', '*.pyc', '*pycache*', '*.bak', '*.dll' }
o.wildmenu = true
o.wildmode = { 'longest:full', 'full' }
o.wildoptions = { 'pum' }

o.pumblend = 10
o.pumheight = 10

-- splits
o.splitbelow = true
o.splitkeep = 'screen'
o.splitright = true

-- spelling
o.spelloptions:append 'camel'

-- lines
o.signcolumn = 'yes:1'
o.relativenumber = true
o.number = true
o.breakat = [[\ \	;:,!?]]
o.foldlevelstart = 99
o.foldlevel = 99
o.foldcolumn = '1'
o.foldenable = true

if vim.treesitter.foldexpr then
    o.foldmethod = 'expr'
    o.foldexpr = [[v:lua.vim.treesitter.foldexpr()]]
else
    o.foldmethod = 'indent'
end

if vim.treesitter.foldtext then
    o.foldtext = [[v:lua.require'core.utils'.fold_text()]]
end

-- file management
o.autowrite = true
o.syntax = 'on'
o.fileformats = { 'unix', 'dos', 'mac' }
o.autoread = true
o.undofile = true
o.undolevels = 10000
o.updatetime = 200
o.shada = ''

-- tabs
o.smartindent = true
o.tabstop = 4
o.softtabstop = 4
o.expandtab = true
o.shiftwidth = 4
o.shiftround = true
o.autoindent = true
o.copyindent = true
o.smarttab = true

-- editing
o.scrolloff = 4
o.sidescrolloff = 8
o.virtualedit = 'onemore'
o.showmatch = true
o.cursorline = true

o.keymodel = { 'startsel', 'stopsel' }

o.completeopt = 'menu,menuone,noselect'
o.conceallevel = 3
o.confirm = true
o.backspace = 'indent,eol,start'
o.whichwrap:append '<,>,[,]'
o.formatoptions = o.formatoptions - 'a' - 't' + 'c' + 'q' - 'o' + 'r' + 'n' + 'j' - '2'

o.smoothscroll = true

-- search & replace
o.hlsearch = true
o.incsearch = true
o.gdefault = true
o.ignorecase = true
o.smartcase = true
o.inccommand = 'nosplit'

-- special
o.listchars = {
    tab = icons.TUI.VisibleSpace .. ' ',
    trail = icons.TUI.VisibleSpace,
    extends = icons.TUI.Ellipsis,
    eol = icons.TUI.LineEnd,
    nbsp = icons.TUI.VisibleSpace,
}

o.fillchars = {
    foldopen = icons.TUI.ExpandedGroup,
    foldclose = icons.TUI.CollapsedGroup,
    fold = ' ',
    foldsep = ' ',
    diff = icons.TUI.MissingLine,
    eob = ' ',
}

o.list = false
o.shortmess:append { W = true, I = true, c = true, C = true }
o.formatoptions = 'jcroqlnt'
o.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'help', 'folds' }

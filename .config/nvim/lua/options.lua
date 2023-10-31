local icons = require 'utils.icons'

-- Global options for neovim
local o = vim.opt
local g = vim.g

-- basic
g.mapleader = ' '
g.maplocalleader = ' '
g.markdown_recommended_style = 0

-- utilities
o.shell = '/bin/bash -i'
o.grepprg = [[rg\ --vimgrep\ --no-heading\ --smart-case]]
o.grepformat = '%f:%l:%c:%m,%f:%l:%m'

-- terminal
o.timeoutlen = 300
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
---@diagnostic disable-next-line: assign-type-mismatch
o.showbreak = icons.TUI.LineContinuation .. ' '
o.nrformats = ''
o.winminwidth = 5
o.ttyfast = true
o.termencoding = 'utf-8'
o.termguicolors = true
o.encoding = 'utf-8'
o.lazyredraw = false
o.laststatus = 2
o.cmdheight = 0
o.wildmenu = true
o.wildmode = 'longest:full,full'
o.pumblend = 10
o.pumheight = 10
o.splitbelow = true
o.splitkeep = 'screen'
o.splitright = true

-- lines
o.signcolumn = 'yes:1'
o.relativenumber = true
o.number = true
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

---@diagnostic disable-next-line: undefined-field
if vim.treesitter.foldtext then
    o.foldtext = [[v:lua.require'utils.ui'.fold_text()]]
end

-- file management
o.autowrite = true
o.filetype = 'on'
o.syntax = 'on'
o.fileformats = 'unix,dos,mac'
o.autoread = true
o.undofile = true
o.undolevels = 10000
o.updatetime = 200

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
o.keymodel = 'startsel,stopsel'
o.completeopt = 'menu,menuone,noselect'
o.conceallevel = 3
o.confirm = true
o.backspace = 'indent,eol,start'
o.whichwrap:append '<,>,[,]'

if vim.fn.has 'nvim-0.10' == 1 then
    o.smoothscroll = true
end

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
o.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'help', 'globals', 'skiprtp', 'folds' }

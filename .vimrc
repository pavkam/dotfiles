" Basic 
set nocompatible
filetype off
syntax on

if 1
  let s:save_cpo = &cpoptions
endif

set cpo&vim
behave mswin

" Settings
let mapleader=","
let maplocalleader="\\"

set noshowmode
set noruler
set noshowcmd
set nowrap
set tabstop=4
set softtabstop=4
set expandtab
set shiftwidth=4
set shiftround
set backspace=indent,eol,start whichwrap+=<,>,[,]
set scrolloff=4
set virtualedit=all
set hlsearch
set incsearch
set gdefault
set listchars=tab:▸\ ,trail:·,extends:#,nbsp:·
set nolist
set pastetoggle=<F2>
set mouse=a
set fileformats="unix,dos,mac"
set formatoptions+=1
set nrformats=
set shortmess+=I
set clipboard=unnamed
set autoread
set updatetime=1000
set autoindent
set copyindent
set number
set showmatch
set ignorecase
set smartcase
set smarttab
set ttyfast
set timeout timeoutlen=1000 ttimeoutlen=50

" Encoding
set termencoding=utf-8
set encoding=utf-8
set lazyredraw
set laststatus=2
set cmdheight=1

" Vim behaviour
set hidden
set switchbuf=useopen
set history=1000
set undolevels=1000
if v:version >= 730
    set undofile
    set undodir=~/.vim/.undo,~/tmp,/tmp
endif
set nobackup
set nowritebackup
set noswapfile
set directory=~/.vim/.tmp,~/tmp,/tmp
set viminfo='20,\"80
set wildmenu
set wildmode=list:full
set wildignore=*.swp,*.bak,*.pyc,*.class,*.o,*.out,*.a
set title
set visualbell
set noerrorbells
set showcmd                     
set nomodeline
set nocursorline
set keymodel=startsel,stopsel

" Key mappings
nnoremap <leader>I :set list!<cr>
nnoremap <leader>N :setlocal number!<cr>

nnoremap / /\v
vnoremap / /\v

nnoremap <C-H> :let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>:%s//
inoremap <C-H> <Esc>:let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>:%s//

vnoremap <BS> d

" Buffer switching using ALT + Left & Right
noremap <A-Left> :bprev<CR>
inoremap <A-Left> <Esc>:bprev<CR>gi
vnoremap <A-Left> <C-C>:bprev<CR>
noremap <A-Right> :bnext<CR>
inoremap <A-Right> <Esc>:bnext<CR>gi
vnoremap <A-Right> :bnext<CR>

" Mapping FZF's Buffers (compensate for terminal handling of Alt as well)
noremap <Esc>z :Buffers<CR>
inoremap <Esc>z <Esc>:Buffers<CR>
vnoremap <Esc>z <C-C>:Buffers<CR>
noremap <A-Z> :Buffers<CR>
inoremap <A-Z> <Esc>:Buffers<CR>
vnoremap <A-Z> <C-C>:Buffers<CR>

" Close and create buffers
noremap <Esc>x :bd<CR>
inoremap <Esc>x <Esc>:bd<CR>
vnoremap <Esc>x <C-C>:bd<CR>
noremap <A-X> :bd<CR>
inoremap <A-X> <Esc>:bd<CR>
vnoremap <A-X> <C-C>:bd<CR>

noremap <Esc><S-X> :bd!<CR>
inoremap <Esc><S-X> <Esc>:bd!<CR>
vnoremap <Esc><S-X> <C-C>:bd!<CR>
noremap <A-S-X> :bd!<CR>
inoremap <A-S-X> <Esc>:bd!<CR>
vnoremap <A-S-X> <C-C>:bd!<CR>

noremap <Esc>n :e new<CR>gi
inoremap <Esc>n <Esc>:e new<CR>gi
vnoremap <Esc>n <C-C>:e new<CR>gi
noremap <A-N> :e new<CR>gi
inoremap <A-N> <Esc>:e new<CR>gi
vnoremap <A-N> <C-C>:e new<CR>gi

" Window switching using Tab
nnoremap <Tab> <c-w>w

" File management
noremap <C-O> :FZF<CR>
inoremap <C-O> <C-O>:FZF<CR>
vnoremap <C-O> <C-C>:FZF<CR>

noremap <C-T> :NERDTreeToggle<CR>
vnoremap <C-T> <C-C>:NERDTreeToggle<CR>
inoremap <C-T> <C-O>:NERDTreeToggle<CR>

noremap <C-S> :update<CR>
noremap <F2> :update<CR>
vnoremap <C-S> <C-C>:update<CR>
vnoremap <F2> <C-C>:update<CR> 
inoremap <C-S> <C-O>:update<CR>
inoremap <F2> <C-O>:update<CR>

" Editor stuff
noremap <C-F> :BLines<CR>
inoremap <C-F> <C-O>:BLines<CR>
vnoremap <C-F> <C-C>:BLines<CR>

" Tab handling
noremap <S-Tab> <<
inoremap <S-Tab> <C-d>

" Editor and selection mapping.

if has("clipboard")
    vnoremap <C-X> "+x
    vnoremap <S-Del> "+x
    vnoremap <C-C> "+y
    vnoremap <C-Insert> "+y
    map <C-V>		"+gP
    map <S-Insert>		"+gP
    cmap <C-V>		<C-R>+
    cmap <S-Insert>		<C-R>+
else
    vnoremap <C-X> d<Esc>i
    vnoremap <S-Del> d<Esc>i
    vnoremap <C-C> y<Esc>i
    vnoremap <C-Insert> y<Esc>i
    map <C-V>		pi
    map <S-Insert>		pi
    cmap <C-V>		<Esc>pi
    cmap <S-Insert>		<Esc>pi
    imap <C-v> <Esc>pi
endif

inoremap <C-X> <C-O>dd
nnoremap <C-X> dd

imap <S-Insert>		<C-V>
vmap <S-Insert>		<C-V>
noremap <C-Q>		<C-V>

if !has("unix")
  set guioptions-=a
endif

noremap <C-Z> u
inoremap <C-Z> <C-O>u
noremap <C-Y> <C-R>
inoremap <C-Y> <C-O><C-R>

if has("gui")
  noremap <M-Space> :simalt ~<CR>
  inoremap <M-Space> <C-O>:simalt ~<CR>
  cnoremap <M-Space> <C-C>:simalt ~<CR>
endif

noremap <C-A> gggH<C-O>G
inoremap <C-A> <C-O>gg<C-O>gH<C-O>G
cnoremap <C-A> <C-C>gggH<C-O>G
onoremap <C-A> <C-C>gggH<C-O>G
snoremap <C-A> <C-C>gggH<C-O>G
xnoremap <C-A> <C-C>ggVG
noremap <C-Tab> <C-W>w
inoremap <C-Tab> <C-O><C-W>w
cnoremap <C-Tab> <C-C><C-W>w
onoremap <C-Tab> <C-C><C-W>w
noremap <C-F4> <C-W>c
inoremap <C-F4> <C-O><C-W>c
cnoremap <C-F4> <C-C><C-W>c
onoremap <C-F4> <C-C><C-W>c


if has("gui")
  " CTRL-F is the search dialog
  noremap  <expr> <C-F> has("gui_running") ? ":promptfind\<CR>" : "/"
  inoremap <expr> <C-F> has("gui_running") ? "\<C-\>\<C-O>:promptfind\<CR>" : "\<C-\>\<C-O>/"
  cnoremap <expr> <C-F> has("gui_running") ? "\<C-\>\<C-C>:promptfind\<CR>" : "\<C-\>\<C-O>/"

  " CTRL-H is the replace dialog,
  " but in console, it might be backspace, so don't map it there
  nnoremap <expr> <C-H> has("gui_running") ? ":promptrepl\<CR>" : "\<C-H>"
  inoremap <expr> <C-H> has("gui_running") ? "\<C-\>\<C-O>:promptrepl\<CR>" : "\<C-H>"
  cnoremap <expr> <C-H> has("gui_running") ? "\<C-\>\<C-C>:promptrepl\<CR>" : "\<C-H>"
endif

set cpo&
if 1
  let &cpoptions = s:save_cpo
  unlet s:save_cpo
endif


" Vundle
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'tpope/vim-fugitive'
Plugin 'bling/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'junegunn/fzf.vim'
Plugin 'sheerun/vim-polyglot'
Plugin 'valloric/youcompleteme'
Plugin 'kien/rainbow_parentheses.vim'
Plugin 'dpelle/vim-languagetool'
Plugin 'scrooloose/nerdtree'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'ryanoasis/vim-devicons'
Plugin 'chrisbra/csv.vim'
Plugin 'junegunn/fzf'

call vundle#end()

filetype plugin indent on

autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() |
    \ quit | endif
autocmd BufEnter * if bufname('#') =~ 'NERD_tree_\d\+' && bufname('%') !~ 'NERD_tree_\d\+' && winnr('$') > 1 |
    \ let buf=bufnr() | buffer# | execute "normal! \<C-W>w" | execute 'buffer'.buf | endif
autocmd BufWinEnter * silent NERDTreeMirror

let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
let g:airline_solarized_bg='dark'

let g:fzf_buffers_jump = 1
let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
let g:fzf_tags_command = 'ctags -R'
let g:fzf_commands_expect = 'alt-enter,ctrl-x'


call pathogen#infect()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File types
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Auto-detection and indentation
filetype plugin indent on

" Run code
augroup run
  au!
  au FileType python noremap <buffer> <F5> :write<CR>:!python %<CR>
  au FileType php noremap <buffer> <F5> :write<CR>:!php -q %<CR>
  au FileType php noremap <buffer> <F6> :write<CR>:!php -l %<CR>
augroup END

" Sensible tab length
set tabstop=2
set shiftwidth=2
set expandtab
set smarttab

" Indenting
set smartindent

" Folding
set foldmethod=syntax
set foldlevel=1

" Toggle folding
nnoremap <Space> za


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Look
" 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

syntax enable

if &t_Co == 256
  colorscheme inkpot
else
  colorscheme torte
endif

" Line numbering
set number

" Show position in file 
set ruler

" Only hilight the matching paren, don't jump to it
set noshowmatch

set laststatus=2
set showbreak=+
set colorcolumn=80

" Scroll before edge is reached
" Vertical
set scrolloff=10
" Horizontal
set sidescrolloff=5
set sidescroll=1

" Set filename as window title
set title

" Dmenu-style menu for commands
set wildmenu


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Key mappings
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Change leader key (NOTE: must appear before <Leader> is used)
let mapleader = ','

" Meta-<number> for buffer navigation
nnoremap 1 :bfirst<CR>
nnoremap 2 :bfirst<CR>:bnext 1<CR>
nnoremap 3 :bfirst<CR>:bnext 2<CR>
nnoremap 4 :bfirst<CR>:bnext 3<CR>
nnoremap 5 :bfirst<CR>:bnext 4<CR>
nnoremap 6 :bfirst<CR>:bnext 5<CR>
nnoremap 7 :bfirst<CR>:bnext 6<CR>
nnoremap 8 :bfirst<CR>:bnext 7<CR>
nnoremap 9 :bfirst<CR>:bnext 8<CR>

nnoremap <S-Tab> :bnext<CR>

" Edit vimrc
nnoremap <Leader>ev :vsplit $MYVIMRC<CR>
nnoremap <Leader>sv :source $MYVIMRC<CR>

" Prev / Next buffer
nnoremap ö :bprev<CR>
nnoremap ä :bnext<CR>

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap q :close<CR> 

" Yank till end of line
nnoremap Y y$

" Improve up/down movement on wrapped lines
nnoremap j gj
nnoremap k gk

" Reselect visual block after indent/outdent
vnoremap < <gv
vnoremap > >gv

" A more handy Esc
inoremap jj <Esc>
inoremap jk <Esc>

" Move stuff around with Alt+jk
noremap <A-j> :m+<CR>
noremap <A-k> :m-2<CR>
inoremap <A-j> <Esc>:m+<CR>
inoremap <A-k> <Esc>:m-2<CR>
vnoremap <A-j> :m'>+<CR>gv
vnoremap <A-k> :m-2<CR>gv

" We've got ÅÄÖ!
nnoremap ö :write<CR>
nnoremap ä :wq<CR>
nnoremap å :SudoWrite<CR>
nnoremap Ö <C-[>
nnoremap Ä <C-]>

" Move in jumplist
" Conflicts with window navigation
"nnoremap <C-j> <C-o>
"nnoremap <C-k> <C-i>

" Digraphs (C-k used by Ultisnips)
inoremap <C-d> <C-k>

" Toggle NERDTree
noremap <C-n> :NERDTreeToggle<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Movements
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Better use for HJKL
noremap J <PageDown>
noremap K <PageUp>
noremap H <Home>
noremap L <End>

" Handy operators
onoremap p i(



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Misc
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Use mouse in text mode
set mouse=a

" Enable hidden buffers
set hidden

set switchbuf=useopen

" Handle \ in Windows file names correctly
set shellslash

" Use sudo when saving with w!!
cmap w!! w !sudo tee % > /dev/null

" No swap or backup files
set noswapfile
set nobackup

" Clear search highlights
noremap <silent> <Leader>/ :nohls<CR>

" Enable paste toggle and map it to F8
set pastetoggle=<F8>

" Disable paste mode when leaving Insert Mode
au InsertLeave * set nopaste

" Make /g default in substitute
set gdefault


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NERDTree
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

cnoreabbrev N NERDTree

" Make VIM CWD follow NerdTree:
let g:NERDTreeChDirMode = 2 
" Show hidden files (to allow .vimrc editing...)
let g:NERDTreeShowHidden = 1 
let g:NERDTreeWinSize = 40 
let g:NERDTreeDirArrows = 0 
" Replace NetRW commands
cnoreabbrev Sex silent! exe 'silent! spl '.expand("%:p:h") 
cnoreabbrev Ex silent! exe 'silent! e '.expand("%:p:h") 
" Show NERDTree on startup
"autocmd VimEnter * if !argc() | NERDTree | endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Mini Buffer Explorer 
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:miniBufExplMapCTabSwitchBufs = 1

" Fix bug that causes syntax hilighting to disappear
" This appears to be fixed by :set hidden
"let g:miniBufExplForceSyntaxEnable = 1


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Powerline
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Type of symbols to use. "Unicode" looks ugly and "fancy" requres special
" modification, so sticking with this.
let g:Powerline_symbols = "compatible"


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Slimv
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let g:slimv_preferred = 'clisp'
let g:slimv_swank_cmd = '! urxvt -e sbcl --load /usr/share/common-lisp/source/slime/start-swank.lisp &'
let g:slimv_repl_split = 4


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TwitVim
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let twitvim_enable_perl = 1
let twitvim_browser_cmd = 'xdg-open'



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Fugitive
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

nnoremap <Leader>gs :Gstatus<CR>
nnoremap <Leader>gc :Gcommit -m "
nnoremap <Leader>gp :Git push<CR>
nnoremap <Leader>gw :Gwrite<CR>


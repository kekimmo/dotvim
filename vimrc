
call pathogen#infect()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File types
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Auto-detection and indentation
filetype plugin indent on

" Run code
if has("autocmd")
	au!
	au FileType python noremap <buffer> <F5> :w<CR> :!python %<CR>
	au FileType php noremap <buffer> <F5> :!php -q %<CR>
	au FileType php noremap <buffer> <F6> :!php -l %<CR>
	au FileType haskell noremap <buffer> <F5> :!runhaskell %<CR>
	au FileType haskell compiler ghc
endif

" Sensible tab length
set tabstop=2
set shiftwidth=2
set expandtab


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Look
" 
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

syntax enable

if &t_Co == 256
	colorscheme inkpot
else
	colorscheme default
endif

" Line numbering
set number

" Show position in file 
set ruler

" Match parentheses
set showmatch

set laststatus=2
set showbreak=+
set colorcolumn=80

" Scroll before edge is reached
" vERTICAl
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

" Change leader key
let mapleader = ','

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Yank till end of line
map Y y$

" Improve up/down movement on wrapped lines
nnoremap j gj
nnoremap k gk

" Reselect visual block after indent/outdent
vnoremap < <gv
vnoremap > >gv

" Use tab for auto completion
function! SuperTab()
	if (strpart(getline('.'),col('.')-2,1)=~'^\W\?$')
		return "\<Tab>"
    else
        return "\<C-n>"
	endif
endfunction
imap <s-tab> <C-R>=SuperTab()<CR>

" Move stuff around with Alt+jk
noremap <A-j> :m+<CR>
noremap <A-k> :m-2<CR>
inoremap <A-j> <Esc>:m+<CR>
inoremap <A-k> <Esc>:m-2<CR>
vnoremap <A-j> :m'>+<CR>gv
vnoremap <A-k> :m-2<CR>gv

noremap <C-n> :NERDTreeToggle<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Misc
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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

" A more handy Esc
inoremap jj <Esc>

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
autocmd VimEnter * if !argc() | NERDTree | endif

noremap <S-Tab> :bnext<CR>


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



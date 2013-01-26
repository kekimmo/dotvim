
call pathogen#infect()

set smartindent

filetype plugin indent on

" 256 colors
set t_Co=256

syntax enable
colors zenburn

" Tab completion, dmenu-style
set wildmenu

" Change leader key
let mapleader = ','

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Reselect visual block after indent/outdent
vnoremap < <gv
vnoremap > >gv

map Y y$

cmap w!! w !sudo tee % > /dev/null

set noswapfile
set nobackup

" Improve up/down movement on wrapped lines
nnoremap j gj
nnoremap k gk

" Clear search highlights
noremap <silent> <Leader>/ :nohls<CR>

" Protect your fat fingers from the evils of <F1>
noremap <F1> <nop>

" Use tab for auto completion
function! SuperTab()
	if (strpart(getline('.'),col('.')-2,1)=~'^\W\?$')
		return "\<Tab>"
    else
        return "\<C-n>"
	endif
endfunction
imap <s-tab> <C-R>=SuperTab()<CR>

" Ö = :
noremap Ö :

" Enable paste toggle and map it to F8
set pastetoggle=<F8>

" A more handy Esc
inoremap jj <Esc>

" Disable paste mode when leaving Insert Mode
au InsertLeave * set nopaste

" Sensible tab length
set tabstop=2
set shiftwidth=2

noremap <A-j> :m+<CR>
noremap <A-k> :m-2<CR>
inoremap <A-j> <Esc>:m+<CR>
inoremap <A-k> <Esc>:m-2<CR>
vnoremap <A-j> :m'>+<CR>gv
vnoremap <A-k> :m-2<CR>gv

set ruler
set showmatch

set laststatus=2

set showbreak=+
set colorcolumn=80

" Line numbering
set nu

" Scroll before edge is reached
" Vertical
set scrolloff=8
set sidescrolloff=8
set sidescroll=1

" Set filename as window title
set title

" Make /g default in substitute
set gdefault

" Run code
if has("autocmd")
	autocmd FileType python noremap <buffer> <F5> :w<CR> :!python %<CR>
	autocmd FileType php noremap <buffer> <F5> :!php -q %<CR>
	autocmd FileType php noremap <buffer> <F6> :!php -l %<CR>
	autocmd FileType haskell noremap <buffer> <F5> :!runhaskell %<CR>
endif

au Bufenter *.hs compiler ghc

" let php_folding=2

cnoreabbrev N NERDTree
:
" Make VIM CWD follow NerdTree:
let g:NERDTreeChDirMode = 2 
" Show hidden files (to allow .vimrc edinting...)
let g:NERDTreeShowHidden = 1 
let g:NERDTreeWinSize = 40 
let g:NERDTreeDirArrows = 0 
" Replace NetRW commands
cnoreabbrev Sex silent! exe 'silent! spl '.expand("%:p:h") 
cnoreabbrev Ex silent! exe 'silent! e '.expand("%:p:h") 
" Show NERDTree on startup
autocmd VimEnter * NERDTree









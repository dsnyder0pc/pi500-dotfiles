set ai
set sw=2
set tabstop=2
set expandtab
set nocp
set ruler

" Show trailing whitepace and spaces before a tab:
:highlight ExtraWhitespace ctermbg=red guibg=red
:autocmd Syntax * syn match ExtraWhitespace /\s\+\%#\@<!$/ containedin=ALL

augroup python
  autocmd!

  autocmd FileType python set cinwords=if,elif,else,for,while,try,except,finally,def,class
  autocmd FileType python set tabstop=8 shiftwidth=2 smarttab expandtab softtabstop=2 autoindent nosmartindent

  let python_space_errors = 1
  setlocal nospell
augroup END

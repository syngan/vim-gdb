scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


nnoremap <Plug>(gdb-step-in)     :<C-u>call gdb#call('step')<CR>
nnoremap <Plug>(gdb-step-over)   :<C-u>call gdb#call('next')<CR>
nnoremap <Plug>(gdb-step-out)    :<C-u>call gdb#call('fin')<CR>
nnoremap <Plug>(gdb-break-point) :<C-u>call gdb#call('break')<CR>
nnoremap <Plug>(gdb-restart)     :<C-u>call gdb#call('restart')<CR>
nnoremap <Plug>(gdb-start)       :<C-u>call gdb#call('start')<CR>
nnoremap <Plug>(gdb-print)       :<C-u>call gdb#call('print')<CR>
vnoremap <Plug>(gdb-print)       :<C-u>call gdb#vcall('print')<CR>

command! -nargs=+ Gdb :call gdb#ex_command(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


nnoremap <Plug>(gdb-step-in)     :<C-u>call gdb#command('step')<CR>
nnoremap <Plug>(gdb-step-over)   :<C-u>call gdb#command('next')<CR>
nnoremap <Plug>(gdb-step-out)    :<C-u>call gdb#command('fin')<CR>
nnoremap <Plug>(gdb-break-point) :<C-u>call gdb#command('break')<CR>

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim


nnoremap <Plug>(gdb-step-in)     :<C-u>call gdb#call('step')<CR>
nnoremap <Plug>(gdb-step-over)   :<C-u>call gdb#call('next')<CR>
nnoremap <Plug>(gdb-step-out)    :<C-u>call gdb#call('fin')<CR>
nnoremap <Plug>(gdb-break-point) :<C-u>call gdb#call('break')<CR>

command! -nargs=+ GdbStart :call gdb#start_cmd(<f-args>)


let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

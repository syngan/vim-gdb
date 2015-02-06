scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:def = {}

function! s:def.next(cnt, ...) abort " {{{
  return gdb#do_command('n ' . a:cnt)
endfunction " }}}

function! s:def.step(cnt, ...) abort " {{{
  return gdb#do_command('s ' . a:cnt)
endfunction " }}}

function! s:def.fin(cnt, ...) abort " {{{
  return gdb#do_command('fin ' . a:cnt)
endfunction " }}}

" @vimlint(EVL103, 1, a:cnt)
function! s:def.break(cnt, fname, lno) abort " {{{
  if !gdb#util#is_gdbwin()
    return
  endif
  return gdb#do_command(printf('b %s:%d', a:fname, a:lno))
endfunction " }}}
" @vimlint(EVL103, 0, a:cnt)

function! gdb#gdb#init() abort " {{{
  return copy(s:def)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

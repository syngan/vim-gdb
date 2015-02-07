scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

function! gdb#util#is_srcwin() abort " {{{
  return exists('w:sggdb_name')
endfunction " }}}

function! gdb#util#is_gdbwin() abort " {{{
  return exists('b:sggdb_name')
endfunction " }}}

function! gdb#util#getid() abort " {{{
  return get(t:, 'sggdb_name', '')
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

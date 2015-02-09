scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:def = {}

function! s:def.next(inf) abort " {{{
  " current buffer/window is debug buffer
  return gdb#do_command('n ' . a:inf.cnt)
endfunction " }}}

function! s:def.step(inf) abort " {{{
  " current buffer/window is debug buffer
  return gdb#do_command('s ' . a:inf.cnt)
endfunction " }}}

function! s:def.fin(...) abort " {{{
  " current buffer/window is debug buffer
  return gdb#do_command('fin')
endfunction " }}}

function! s:def.break(inf) abort " {{{
  " current buffer/window is debug buffer
  return gdb#do_command(printf('b %s:%d', a:inf.fname, a:inf.lno))
endfunction " }}}

function! s:def.is_quitcmd(str) abort " {{{
  return a:str =~# '^\s*q\%[uit]\>'
endfunction " }}}

function! s:def.is_igncmd(str) abort " {{{
  " $B<B9T$KD>@\4X78$N$J$$%3%^%s%I(B.
  " $B%=!<%k%U%!%$%k$NI=<($rJQ99$9$kI,MW$,$J$$$H$+(B.
  return a:str =~# '^\s*\(bt\|l\%[ist]\|i\%[nfo]\|f\>\)\>'
endfunction " }}}

function! s:def.parse_fname(str) abort " {{{
  " $B<B9T%m%0$+$i!"I=<($,I,MW$J%U%!%$%kL>!"9THV9f$rJV$9(B.
  " @return a list of filename and lineno.
  let m = matchlist(a:str, 'at \(.*\):\(\d\+\)$')
  if m != []
    return [m[1], str2nr(m[2])]
  endif
  if a:str =~# '^\d\+\s'
    return ['', str2nr(matchstr(a:str, '^\d\+\ze\s'))]
  else
    return ['', -1]
  endif
endfunction " }}}

function! gdb#gdb#init() abort " {{{
  return copy(s:def)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

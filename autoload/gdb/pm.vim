" modified ver of vital.vim ProcessManager.vim

let s:save_cpo = &cpo
set cpo&vim

let s:_processes = {}

function! gdb#pm#import() abort " {{{
  let pm = s:
  let pm.is_available = function('s:is_available')
  let pm.status = function('s:status')
  let pm.term = function('s:term')
  let pm.read = function('s:read')
  let pm.read_wait = function('s:read_wait')
  let pm.write = function('s:write')
  let pm.writeln = function('s:writeln')
  let pm.touch = function('s:touch')
  let pm.kill = function('s:kill')
  return pm
endfunction " }}}

function! s:has_vimproc() abort " {{{
  if !exists('s:exists_vimproc')
    try
      call vimproc#version()
      let s:exists_vimproc = 1
    catch
      let s:exists_vimproc = 0
    endtry
  endif
  return s:exists_vimproc
endfunction " }}}

function! s:is_available() abort " {{{
  return s:has_vimproc() && has('reltime')
endfunction " }}}

function! s:touch(name, cmd) abort " {{{
  if has_key(s:_processes, a:name)
    return 'existing'
  else
    let p = vimproc#popen3(a:cmd)
    let s:_processes[a:name] = p
    return 'new'
  endif
endfunction " }}}

function! s:_stop(i, ...) abort " {{{
  let p = s:_processes[a:i] " {{{ " }}}
  call p.kill(get(a:000, 0, 0) ? g:vimproc#SIGKILL : g:vimproc#SIGTERM)
  " call p.waitpid()
  unlet s:_processes[a:i]
  if has_key(s:state, a:i)
    unlet s:state[a:i]
  endif
endfunction " }}}

function! s:term(i) abort " {{{
  return s:_stop(a:i, 0)
endfunction " }}}

function! s:kill(i) abort " {{{
  return s:_stop(a:i, 1)
endfunction " }}}

function! s:read(i, endpatterns) abort " {{{
  return s:read_wait(a:i, 0.05, a:endpatterns)
endfunction " }}}

let s:state = {}

function! s:substitute_last(expr, pat, sub) abort " {{{
  return substitute(a:expr, printf('.*\zs%s', a:pat), a:sub, '')
endfunction " }}}

function! s:read_wait(i, wait, endpatterns) abort " {{{
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif

  let p = s:_processes[a:i]

  if s:status(a:i) ==# 'inactive'
    let s:state[a:i] = 'inactive'
    return [p.stdout.read(), p.stderr.read(), 'inactive']
  endif

  let out_memo = ''
  let err_memo = ''
  let lastchanged = reltime()
  while 1
    let [x, y] = [p.stdout.read(), p.stderr.read()]
    if x ==# '' && y ==# ''
      if str2float(reltimestr(reltime(lastchanged))) > a:wait
        let s:state[a:i] = 'reading'
        return [out_memo, err_memo, 'timeout']
      endif
    else
      let lastchanged = reltime()
      let out_memo .= x
      let err_memo .= y
      for pattern in a:endpatterns
        if out_memo =~ ("\\(^\\|\n\\)" . pattern)
          let s:state[a:i] = 'idle'
          return [s:substitute_last(out_memo, pattern, ''), err_memo, 'matched']
        endif
      endfor
    endif
  endwhile
endfunction " }}}

function! s:write(i, str) abort " {{{
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif
  if s:status(a:i) ==# 'inactive'
    return 'inactive'
  endif

  let p = s:_processes[a:i]
  call p.stdin.write(a:str)

  return 'active'
endfunction " }}}

function! s:writeln(i, str) abort " {{{
  return s:write(a:i, a:str . "\n")
endfunction " }}}

function! s:status(i) abort " {{{
  if !has_key(s:_processes, a:i)
    throw printf("ProcessManager doesn't know about %s", a:i)
  endif
  let p = s:_processes[a:i]
  " vimproc.kill isn't to stop but to ask for the current state.
  " return p.kill(0) ? 'inactive' : 'active'
  " ... checkpid() checks if the process is running AND does waitpid() in C,
  " so it solves zombie processes.
  return get(p.checkpid(), 0, '') ==# 'run'
        \ ? 'active'
        \ : 'inactive'
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0:

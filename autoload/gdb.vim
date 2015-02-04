scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:name = 'sg_gdb'
let s:prompt = '(gdb) '
let s:V = vital#of(s:name)
let s:PM = s:V.import('ProcessManager')
let s:gdb = {}

:highlight sggdb_hl_group  cterm=bold,underline ctermfg=red ctermbg=black
:highlight sggdb_hl_prompt cterm=bold           ctermfg=139 ctermbg=black
:highlight sggdb_hl_input  ctermfg=yellow ctermbg=black

function! s:exit(name) abort " {{{
  only!
  call gdb#kill(a:name)
endfunction " }}}

function! gdb#launch(args) abort " {{{
  if !s:PM.is_available()
    " +reltime
    " vimproc
    throw "vimproc?"
  endif
  let name = s:name
  call s:PM.touch(name, 'gdb ' . a:args)

  " タブを開く.
  :tabnew
  let s:gdb[name] = {}
  let s:gdb[name].file_winnr = gift#uniq_winnr()
  let s:gdb[name].hlid = -1
  :rightbelow new
  :e '[sg-gdb-log]'
  let b:sggdb_name = name
  call matchadd('sggdb_hl_prompt', s:prompt)
  call matchadd('sggdb_hl_input', s:prompt . '\zs.*')
  inoremap <buffer> <CR> <ESC>:call gdb#execute('i')<CR>
  nnoremap <buffer> <CR> :call gdb#execute('n')<CR>
  setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted
  let [out, err, type] = s:PM.read_wait(b:sggdb_name, 0.5, [s:prompt])
  if type !=# 'matched'
    " some error
    throw err
  endif
  silent $ put = out
  silent $ put = s:prompt
  execute 'normal!' 'A'
  autocmd QuitPre <buffer> call s:exit(b:sggdb_name)
endfunction " }}}

function! gdb#kill(...) abort " {{{
  let name = a:0 > 0 ? a:1 : b:sggdb_name
  if has_key(s:gdb, name)
    echo s:PM.kill(name)
    unlet! s:gdb[name]
  endif
endfunction " }}}

function! s:parse_lno(str) abort " {{{
  " ここを修正時には s:showpage の filter()も修正が必要.
  if a:str =~# '^\d\+\s'
    return str2nr(matchstr(a:str, '^\d\+\ze\s'))
  else
    return -1
  endif
endfunction " }}}

function! s:parse_fname(str) abort " {{{
  let m = matchlist(a:str, 'at \(.*\):\(\d\+\)$')
  if m == []
    return ['', -1]
  else
    return [m[1], str2nr(m[2])]
  endif
endfunction " }}}

function! s:show_page(out) abort " {{{
  let lines = split(a:out, '\n')

  " @see s:parse_lno
  " @see s:parse_fname
  let lines = filter(lines, 
        \ 'v:val =~# ''at .*:\d\+'' ||'
        \ . 'v:val =~# ''^\d\+\s''')
  call vimconsole#log('show page')
  call vimconsole#log(lines)

  let found_lno = 0
  let update = 0
  for i in range(len(lines)-1, 0, -1)
    let str = lines[i]
    if !found_lno
      let lno = s:parse_lno(str)
      if lno > 0
        let s:gdb[b:sggdb_name].lno = lno
        let found_lno = 1
        let update = 1
        continue
      endif
    endif

    let [fname, lno] = s:parse_fname(str)
    if fname != ''
      if !found_lno
        let s:gdb[b:sggdb_name].lno = lno
        let update = 1
      endif
        let s:gdb[b:sggdb_name].fname = fname
      break
    endif
  endfor

  if update
    let name = b:sggdb_name
    if filereadable(s:gdb[name].fname)
      let fname = s:gdb[name].fname
    else
      let fname = findfile(s:gdb[name].fname, './**')
    endif
    call vimconsole#log('org:fname=' . s:gdb[name].fname)
    call vimconsole#log('new:fname=' . fname)
    if fname !=# ''
      let winnr = gift#uniq_winnr()
      let save_pos = getpos('.')
      try
        call gift#jump_window(s:gdb[name].file_winnr)
        if s:gdb[name].hlid > 0
          call matchdelete(s:gdb[name].hlid)
        endif
        execute printf('silent :e +%d `=fname`', s:gdb[name].lno)
        let s:gdb[name].hlid = matchadd('sggdb_hl_group', printf('\%%%dl', s:gdb[name].lno))
        call vimconsole#log(printf('hlid=%s', string(s:gdb[name].hlid)))
      finally
        call gift#jump_window(winnr)
        call setpos('.', save_pos)
      endtry
    endif
  endif

  return lines
endfunction " }}}

function! gdb#execute(mode) abort " {{{
  if !exists('b:sggdb_name')
    echoerr 'sggdb: gdb#launch() is not called'
    return
  endif
  let line = getline('.')
  if line =~# '^' . s:prompt
    let str = matchstr(line, printf('^%s\zs.*$', s:prompt)) 
    let out = s:write(str)
  elseif line !~# '(y or n)'
    let str = matchstr(line, '(y or n) \zs.*$')
    let out = s:write(str)
  else
    return
  endif

  call vimconsole#log(out)
  if str !~# '^\s*bt\s*'
    call s:show_page(out)
  endif
  if a:mode ==# 'i'
    " insert-mode になってほしい.
    startinsert!
  endif
endfunction " }}}

function! s:write(str) abort " {{{
  if get(g:, 'sggdb_verbose', 0)
    redraw | echo printf('send [%s]', a:str)
  endif
  call vimconsole#log(printf('send [%s]', a:str))
  call s:PM.writeln(b:sggdb_name, a:str)
  if line('.') < line('$') 
    execute printf("%d,$delete _", line('.')+1)
  endif
  while 1
    let [out, err, type] = s:PM.read(b:sggdb_name, [s:prompt])
    if type ==# 'matched'
      " some error
      break
    endif
    if type ==# 'timedout'
      " 非同期に処理したいところ
      " @TODO wait している以外の待ち, 
      " @TODO コマンドの入力待ちとかにどう対応するか
      silent $ put = out
      if out =~# '(y or n) $'
        break
      endif

      continue
    endif
    
    echoerr printf('type=%s, err=%s', type, err)
    return
  endwhile
  silent $ put = out
  silent $ put = s:prompt
  $
  return out
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

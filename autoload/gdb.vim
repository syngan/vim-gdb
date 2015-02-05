scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:name = 'sg_gdb'
let s:prompt = '(gdb) '
let s:PM = gdb#pm#import()
let s:gdb = {}

:highlight sggdb_hl_group  cterm=bold,underline ctermfg=red ctermbg=black
:highlight sggdb_hl_prompt cterm=bold           ctermfg=139 ctermbg=black
:highlight sggdb_hl_input  ctermfg=yellow ctermbg=black

function! s:exit(name) abort " {{{
  only
  call gdb#kill(a:name)
endfunction " }}}

function! gdb#pm() abort " {{{
  return s:PM
endfunction " }}}

function! s:open_srcwin(name) abort " {{{
  :new
  if !has_key(s:gdb, a:name)
    let s:gdb[a:name] = {}
    let s:gdb[a:name].hlid = -1 " ハイライト中の highlight-id
  endif
  let s:gdb[a:name].file_winnr = gift#uniq_winnr()
endfunction " }}}

function! gdb#launch(cmd_args) abort " {{{
  if !s:PM.is_available()
    " +reltime
    " vimproc
    throw 'vimproc and +reltime are required'
  endif
  let name = s:name
  call s:PM.touch(name, 'gdb ' . a:cmd_args)

  " タブを開く.
  :tabnew
  :e '[sg-gdb-log]'
  let b:sggdb_name = name
  call matchadd('sggdb_hl_prompt', s:prompt)
  call matchadd('sggdb_hl_input', s:prompt . '\zs.*')
  inoremap <silent> <buffer> <CR> <ESC>:call gdb#execute('i')<CR>
  nnoremap <silent> <buffer> <CR> :call gdb#execute('n')<CR>
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

  let winnr = gift#uniq_winnr()

  " ソースコード表示用
  call s:open_srcwin(name)

  " 元の位置に戻る.
  call gift#jump_window(winnr)
endfunction " }}}

function! gdb#kill(...) abort " {{{
  let name = a:0 > 0 ? a:1 : b:sggdb_name
  if has_key(s:gdb, name)
    echo s:PM.kill(name)
    unlet! s:gdb[name]
  endif
endfunction " }}}

function! s:parse_fname(str) abort " {{{
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

function! s:show_page(out) abort " {{{
  let lines = split(a:out, '\n')

  " @see s:parse_lno
  " @see s:parse_fname
  let update = 0
  for str in lines
    let [fname, lno] = s:parse_fname(str)
    if fname !=# ''
      let s:gdb[b:sggdb_name].fname = fname
    endif
    if lno > 0
      let s:gdb[b:sggdb_name].lno = lno
      let update = 1
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
        let ret = gift#jump_window(s:gdb[name].file_winnr)
        if ret == -1
          call s:open_srcwin(name)
        endif
        if s:gdb[name].hlid > 0
          try
            call matchdelete(s:gdb[name].hlid)
          catch /.*E803: .*/
          endtry
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

function! s:is_igncmd(str) abort " {{{
  " 実行に直接関係のないコマンド.
  " ソールファイルの表示を変更する必要がないとか.
  return a:str =~# '^\s*\(bt\|l\%[ist]\|i\%[nfo]\)\>'
endfunction " }}}

function! s:is_quit(str) abort " {{{
  return a:str =~# '^\s*q\%[uit]\>'
endfunction " }}}

function! gdb#execute(mode) abort " {{{
  if !exists('b:sggdb_name')
    echoerr 'sggdb: gdb#launch() is not called'
    return
  endif
  if !has_key(s:gdb, b:sggdb_name)
    " killed
    return
  endif
  let line = getline('.')
  if line =~# '^' . s:prompt
    let str = matchstr(line, printf('^%s\zs.*$', s:prompt))
  elseif line !~# '(y or n)'
    " なんだろう
    " Start it from the beginning? (y or n) [answered Y; input not from terminal]
    let str = matchstr(line, '(y or n) \zs.*$')
  else
    return
  endif

  if s:is_quit(str)
    call s:PM.writeln(b:sggdb_name, str)
    call gdb#kill()
    silent $ put = 'bye'
    return
  endif
  let out = s:write(str)
  call vimconsole#log(out)
  if !s:is_igncmd(str)
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
    execute printf('%d,$delete _', line('.')+1)
  endif
  while 1
    let [out, err, type] = s:PM.read(b:sggdb_name, [s:prompt])
    if type ==# 'matched'
      " some error
      break
    endif
    if type ==# 'timeout'
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
  if out !=# ''
    silent $ put = out
  endif
  if err !=# ''
    silent $ put = err
  endif
  silent $ put = s:prompt
  $
  return out
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

scriptencoding utf-8

" b:sggdb_name: gdb-debug buffer
" w:sggdb_name: src-view window
" t:sggdb_name: tab

let s:save_cpo = &cpo
set cpo&vim

let s:id = 0
let s:prompt = '(gdb) '
let s:PM = gdb#pm#import()
let s:gdb = {}

:highlight sggdb_hl_group  cterm=bold,underline ctermfg=red ctermbg=black
:highlight sggdb_hl_prompt cterm=bold           ctermfg=139 ctermbg=black
:highlight sggdb_hl_input  ctermfg=yellow ctermbg=black

function! gdb#launch_cmd(kind, ...) abort " {{{
  call vimconsole#log("lcm=")
  call vimconsole#log(a:000)
  if a:0 == 0
    return gdb#launch(a:kind)
  else
    return gdb#launch(a:kind, join(a:000, ' '))
  endif
endfunction " }}}

function! s:exit(name) abort " {{{
  only
  call gdb#kill(a:name)
endfunction " }}}

function! s:open_srcwin(name) abort " {{{
  :new
  let s:gdb[a:name].file_winnr = gift#uniq_winnr()
  let w:sggdb_name = a:name
endfunction " }}}

function! gdb#call(cmd) abort " {{{
  " public
  " a:cmd is 'next', 'step', 'fin', ...
  " break-point だけはどこからでも付けられても良い気がするが. さてさて.
  let name = gdb#util#getid()
  if !has_key(s:gdb, name)
        \ || !has_key(s:gdb[name], a:cmd)
        \ || type(s:gdb[name][a:cmd]) != type(function('tr'))
    return
  endif

  let dict = s:gdb[name]
  let winnr = gift#uniq_winnr()
  let do_jump = (dict.debug_winnr != winnr)
  if do_jump
    let inf = {'fname': expand('%:t'), 'lno': line('.')}
    if gift#jump_window(dict.debug_winnr) < -1
      return
    endif
  else
    let inf = {'fname': dict.fname, 'lno': dict.lno}
  endif
  let inf.cnt = v:count1
  try
    call dict[a:cmd](inf)
  finally
    if do_jump
      call gift#jump_window(winnr)
    endif
  endtry

endfunction " }}}

function! gdb#do_command(cmd, ...) abort " {{{
  " the current buffer/window is debug buffer/window
  " send a:cmd to 'gdb'
  " called from gdb#do_cursorline and gdb#xxx#{step,next,fin,...}
  if !gdb#util#is_gdbwin(s:gdb)
    return
  endif
  let dict = s:gdb[b:sggdb_name]
  let str = a:cmd
  if a:0 == 0
    " send command from src buffer
    let line = getline('$')
    if line == s:prompt
      silent $ delete _
    endif
    silent $ put = s:prompt . a:cmd
  endif

  if dict.is_quitcmd(str)
    call s:PM.writeln(b:sggdb_name, str)
    call gdb#kill()
    silent $ put = 'bye'
    return
  endif
  let out = s:write(str)
  if !dict.is_igncmd(str)
    call s:show_page(out)
  endif
endfunction " }}}

function! s:newid() abort " {{{
  " 一意 ID
  let s:id += 1
  return s:id
endfunction " }}}

function! s:newtab(name) abort " {{{
  :tabnew
  :e `=printf('[sg-gdb-%d]', a:name)`
  let b:sggdb_name = a:name
  let t:sggdb_name = a:name
  call matchadd('sggdb_hl_prompt', s:prompt)
  call matchadd('sggdb_hl_input', s:prompt . '\zs.*')
  inoremap <silent> <buffer> <CR> <ESC>:<C-u>call gdb#do_cursorline('i')<CR>
  nnoremap <silent> <buffer> <CR> :<C-u>call gdb#do_cursorline('n')<CR>
  setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted
  let [out, err, type] = s:PM.read_wait(a:name, 0.5, [s:prompt])
  if type !=# 'matched'
    " some error
    throw err
  endif
  silent $ put = out
  silent $ put = s:prompt
  execute 'normal!' '$'
  autocmd QuitPre <buffer> call s:exit(b:sggdb_name)

  return gift#uniq_winnr()
endfunction " }}}

function! s:config(kind) abort " {{{
  if exists('g:gdb#config') && has_key(g:gdb#config, a:kind)
    let config = copy(g:gdb#config[a:kind])
  else
    let config = {}
  endif
  if !has_key(config, 'srcdir')
    let config.srcdir = ['./**']
  elseif type(config.srcdir) != type([])
    let config.srcdir = [config.srcdir]
  endif

  if !has_key(config, 'starup_commands')
    let config.starup_commands = []
  elseif type(config.starup_commands) != type([])
    let config.starup_commands = [config.starup_commands]
  endif

  if !has_key(config, 'args') || type(config.args) != type('')
    let config.args = a:kind
  endif

  return config
endfunction " }}}

function! s:startup_command(dict) abort " {{{
  for cmd in a:dict.config.starup_commands
    call gdb#do_command(cmd)
  endfor
endfunction " }}}

function! gdb#launch(kind, ...) abort " {{{
  if !s:PM.is_available()
    " +reltime
    " vimproc
    throw 'vimproc and +reltime are required'
  endif
  let name = s:newid()
  let config = s:config(a:kind)
  let args = a:0 == 0 ? config.args : a:1
  call s:PM.touch(name, 'gdb ' . args)

  " タブを開く.
  let winnr = s:newtab(name)
  let s:gdb[name] = gdb#gdb#init()
  let s:gdb[name].hlid = -1 " ハイライト中の highlight-id
  let s:gdb[name].debug_winnr = winnr
  let s:gdb[name].config = config

  " ソースコード表示用
  call s:open_srcwin(name)

  " 元の位置に戻る.
  call gift#jump_window(winnr)

  call s:startup_command(s:gdb[name])

  return name
endfunction " }}}

function! gdb#kill(...) abort " {{{
  let name = a:0 > 0 ? a:1 : gdb#util#getid()
  if has_key(s:gdb, name)
    echo s:PM.kill(name)
    unlet! s:gdb[name]
  endif
endfunction " }}}

function! s:searchfile(dict, name) abort " {{{
  if filereadable(a:name)
    let fname = a:dict.fname
  else
    for dir in a:dict.config.srcdir
      let fname = findfile(a:name, dir)
      if fname !=# ''
        let a:dict.fname = fname
        break
      endif
    endfor
  endif

  return fname
endfunction " }}}

function! s:parse_out(dict, out) abort " {{{
  " parse output (stdout) of GDB,
  " get file name and lineno.
  let lines = split(a:out, '\n')
  let dict = a:dict
  let update = 0
  for str in lines
    let [fname, lno] = dict.parse_fname(str)
    if fname !=# ''
      let dict.fname = fname
    endif
    if lno > 0
      let dict.lno = lno
      let update = 1
    endif
  endfor
  return update
endfunction " }}}

function! s:show_page(out) abort " {{{
  " the current buffer/window is debug buffer/window

  " @see s:parse_lno
  " @see s:parse_fname
  let name = b:sggdb_name
  let dict = s:gdb[name]
  let update = s:parse_out(dict, a:out)

  if update
    let fname = s:searchfile(dict, dict.fname)
    if fname !=# ''
      let winnr = gift#uniq_winnr()
      let save_pos = getpos('.')
      try
        let ret = gift#jump_window(dict.file_winnr)
        if ret == -1
          call s:open_srcwin(name)
        endif
        if dict.hlid > 0
          try
            call matchdelete(dict.hlid)
          catch /.*E803: .*/
          endtry
        endif
        execute printf('silent :e +%d `=fname`', dict.lno)
        let dict.hlid = matchadd('sggdb_hl_group', printf('\%%%dl', dict.lno))
        nmap <silent> <buffer> <C-N> <Plug>(gdb-step-over)
        nmap <silent> <buffer> <C-I> <Plug>(gdb-step-in)
        nmap <silent> <buffer> <C-F> <Plug>(gdb-step-out)
        nmap <silent> <buffer> <C-B> <Plug>(gdb-break-point)
      finally
        call gift#jump_window(winnr)
        call setpos('.', save_pos)
      endtry
    endif
  endif

endfunction " }}}

function! gdb#do_cursorline(mode) abort " {{{
  " gdb-buffer で <CR> 時にカレント行の内容を実行する.
  if !exists('b:sggdb_name')
    echoerr 'gdb#launch() is not called'
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

  call gdb#do_command(str, 1)

  if a:mode ==# 'i'
    " insert-mode になってほしい.
    startinsert!
  endif
endfunction " }}}

function! s:write(str) abort " {{{
  " send a:str to GDB process
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
  execute 'normal!' '$'
  return out
endfunction " }}}

function! gdb#dict() abort " {{{
  " debug.
  return s:gdb
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:

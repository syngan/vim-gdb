vim-gdb
=====================

- required
   - [Shougo/vimproc](https://github.com/Shougo/vimproc.vim)
   - [osyo-manga/vim-gift](https://github.com/osyo-manga/vim-gift)
   - +reltime

- gdb 連携
- 入力待ちをするようなコマンドには未対応. どうすればいいのかわからない.

1. `call gdb#start('hoge')` で `gdb hoge` を実行する感じ.
    - src を表示する window (src-win) と, gdb コマンド情報を示す window (gdb-win) をもつ新しいタブを開く
2. gdb-win でプロンプト `(gdb) ` の後に適当にコマンドをうち `<CR>`.
   または normal-mode で入力済みの行で `<CR>`
3. src-win で
    - `<C-I>` すると step-in
    - `<C-N>` すると step-over
    - `<C-F>` すると step-out
    - `<C-B>` するとブレイクポイントを設定する

## コマンド

:Gdb -start {kind} {command-line}
   - gdb#start() のコマンド版
:Gdb {command-line}
   - gdb にコマンドを送る
   - e.g. :Gdb next

## 関数

- gdb#start({kind} [, {command-line}])
   - `kind`: `g:gdb#config` で設定する情報. 通常は実行ファイル名と合わせる.
   - `command-line` を省略すると, `gdb {g:gdb#config[kind].args}` が実行される.
   - `command-line` が指定された場合は, `gdb {command-line}` が実行される

## 設定

- `g:gdb#config` は辞書で, 任意のキー (`gdb#start()` の `kind`) と, 辞書を値とする.
-  辞書は以下のキーをもつ 
   - 'srcdir': ソースファイルを `findfile()` で探索するディレクトリ. デフォルトは `./**`.
               文字列、または文字列のリストで指定する.
   - 'startup_commands': `.gdbinit` と同じようなもの.
   - 'args': `gdb#start` の {command-line} デフォルト値. デフォルトは {kind}.



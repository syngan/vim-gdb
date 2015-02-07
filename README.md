vim-gdb
=====================

- required
   - [Shougo/vimproc](https://github.com/Shougo/vimproc.vim)
   - [osyo-manga/vim-gift](https://github.com/osyo-manga/vim-gift)

- gdb 連携
- 入力待ちをするようなコマンドには未対応. どうすればいいのかわからない.
- 'list' をする必要がない程度の機能のみ

1. `call gdb#launch('hoge')` で `gdb hoge` を実行する感じ.
    - src を表示する window (src-win) と, gdb コマンド情報を示す window をもつ新しいタブを開く
2. `(gdb) ` の後に適当にコマンドを打つだけ.
3. src-win で
    - `<C-I>` すると step-in
    - `<C-N>` すると step-over
    - `<C-F>` すると step-out
    - `<C-B>` するとブレイクポイントを設定する

## コマンド

- gdb#launch({kind} [, {command-line}])
   - `kind`: `g:gdb#config` で設定する情報. 通常は実行ファイル名と合わせる.
   - `command-line` を省略すると, `gdb {kind}` が実行される.
   - `command-line` が指定された場合は, `gdb {command-line}` が実行される

## 設定

- `g:gdb#config` は辞書で, 任意のキー (`gdb#launch()` の `kind`) と, 辞書を値とする.
-  辞書は以下のキーをもつ 
   - 'srcdir': ソースファイルを `findfile()` で探索するディレクトリ. デフォルトは `./**`.
               文字列、または文字列のリストで指定する.



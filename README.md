# FAX送信用PDFの作り方

Mac のターミナルで、PDFをインターネットFAX向けの A4・200dpi に変換します。元の文字や図は、FAXで送れる画像になります。縦に長いページは、幅を A4 に合わせ、はみ出した分を次の A4 ページに分けます。

使うファイルは同じフォルダに置いたままにしてください。

```text
fax-pdf-gray-200dpi.sh        MOVFAX向け
fax-pdf-bilevel-g4-200dpi.sh  秒速FAX向け
fax-pdf-common.sh             内部用。このファイルは実行しない
```

## 非エンジニア向け

### どちらのコマンドを使うか

送るサービスで選びます。

| 送るサービス | 実行するファイル | 仕上がり | スクリプト側の目安 |
| --- | --- | --- | --- |
| MOVFAX | `fax-pdf-gray-200dpi.sh` | グレーの画像 | 10MB を超えると警告。PDFはできる |
| 秒速FAX | `fax-pdf-bilevel-g4-200dpi.sh` | 白と黒だけの画像 | 10ページまで、1MBまで |

用紙の向きは、コマンドに何も付けないと **A4横** です。縦長の書類は `-p` を付けて **A4縦** にします。

### 1. ターミナルを開く

1. Spotlight（Command + スペース）を開く
2. `ターミナル` と入力して Enter

以降のコマンドは、このターミナルに貼り付けて Enter です。

### 2. 必要なソフトを入れる

この手順は初回だけです。`brew` と打って `command not found` と出る場合は、先に [Homebrew](https://brew.sh/) を入れてください。インストールの最後に「Next steps」が出たら、そこに書かれたコマンドを実行し、ターミナルを開き直します。

```bash
brew install poppler imagemagick uv
uv tool install img2pdf
```

初回の `brew install` は数分かかることがあります。

続けて、今開いているターミナルからも `img2pdf` を使えるようにします。

```bash
uv tool update-shell
```

このあと **ターミナルをいったん終了し、開き直してください。**

開き直したターミナルで、次の3つを順に実行します。それぞれバージョンが表示されれば準備完了です。

```bash
pdftoppm -v
magick -version
img2pdf --version
```

### 3. スクリプトのフォルダへ移動する

ターミナルに `cd ` と入力します（`cd` のうしろに半角スペース）。Finder から、3つのスクリプトが入ったフォルダをターミナルへドラッグし、Enter を押します。

例:

```bash
cd /Users/あなたの名前/Develop/fax-ready-pdf
```

初回だけ、2つのスクリプトを実行できる状態にします。

```bash
chmod +x fax-pdf-gray-200dpi.sh fax-pdf-bilevel-g4-200dpi.sh
```

### 4. PDFを変換する

コマンドを途中まで入力し、うしろの半角スペースのあとに、Finder から変換したい PDF をドラッグして Enter です。

MOVFAX、A4横:

```bash
./fax-pdf-gray-200dpi.sh 
```

MOVFAX、A4縦:

```bash
./fax-pdf-gray-200dpi.sh -p 
```

秒速FAX、A4横:

```bash
./fax-pdf-bilevel-g4-200dpi.sh 
```

秒速FAX、A4縦:

```bash
./fax-pdf-bilevel-g4-200dpi.sh -p 
```

ドラッグしたあとは、次のような1行になります。

```bash
./fax-pdf-gray-200dpi.sh -p /Users/あなたの名前/Desktop/見積書.pdf
```

変換中は `[1/4]` から `[4/4]` までの進捗が出ます。最後に `Created:` で始まる行が出れば完了です。

```text
Created: /Users/あなたの名前/Desktop/見積書-fax-gray-200dpi-a4-portrait.pdf (0.42 MiB, 2 pages)
```

できた PDF は、元の PDF と同じフォルダにできます。名前を省略したときの例は次のとおりです。

```text
見積書.pdf
  MOVFAX・横    見積書-fax-gray-200dpi-a4-landscape.pdf
  MOVFAX・縦    見積書-fax-gray-200dpi-a4-portrait.pdf
  秒速FAX・横   見積書-fax-bilevel-g4-200dpi-a4-landscape.pdf
  秒速FAX・縦   見積書-fax-bilevel-g4-200dpi-a4-portrait.pdf
```

保存名を自分で決めるときは、PDFをドラッグしたあとに、保存したい名前を足します。

```bash
./fax-pdf-gray-200dpi.sh -p /Users/あなたの名前/Desktop/見積書.pdf /Users/あなたの名前/Desktop/FAX用.pdf
```

### 5. 送る前に見るところ

- 最後の行のページ数と MiB（ファイルサイズ）を確認する
- 仕上がりを開いて、文字が読めるか、ページの切れ目がおかしくないかを見る
- MOVFAX 用で `Warning: output exceeds configured limit` と出たときは、10MB を超えています。PDFはできています
- 秒速FAX 用で `Error: output has ... pages` と出たときは、10ページを超えたため PDF はできていません
- 秒速FAX 用でサイズの `Warning:` が出て処理が失敗したときは、1MB を超えています。PDF自体はできています

### うまくいかないとき

| 画面に出ること | 対処 |
| --- | --- |
| `command not found: brew` | Homebrew を入れて、ターミナルを開き直す |
| `required command not found: pdftoppm` | `brew install poppler` を実行する |
| `required command not found: magick` | `brew install imagemagick` を実行する |
| `required command not found: img2pdf` | `uv tool install img2pdf` のあと `uv tool update-shell` を実行し、ターミナルを開き直す |
| `Permission denied` | スクリプトのフォルダで、手順3の `chmod +x ...` を実行する |
| `file not found` | PDFをもう一度ドラッグする。ファイル名の前に半角スペースがあることを確認する |
| `fax-pdf-common.sh` が見つからない、という内容 | 3つのファイルを同じフォルダに戻す |

## エンジニア・開発者向け

### 構成

`fax-pdf-gray-200dpi.sh` と `fax-pdf-bilevel-g4-200dpi.sh` がプリセットです。どちらも同じディレクトリの `fax-pdf-common.sh` を `source` し、`fax_main` を呼びます。共通ファイル単体の実行では変換は始まりません。

| プリセット | タグ | 画像 | ページ上限 | サイズ上限 | サイズ超過 |
| --- | --- | --- | --- | --- | --- |
| Gray（MOVFAX） | `fax-gray-200dpi` | 8bit グレースケール JPEG、品質 85 | なし | 10 MiB | 警告のみ。終了コード 0。PDFは作成済み |
| Bilevel（秒速FAX） | `fax-bilevel-g4-200dpi` | 1bit、しきい値 55%、CCITT Group 4 | 10 | 1 MiB | 警告のあと終了コード 2。PDFは作成済み |

ページ上限を超えた場合は `img2pdf` の前に終了コード 1 で止まります。

JPEG 品質としきい値は各プリセット内の固定値です。環境変数では変わりません。

### 依存コマンド

- `pdftoppm`（poppler）
- `magick`（ImageMagick 7）
- `img2pdf`

### 処理

1. 元PDFを `RENDER_DPI`（既定 400）でグレースケール PNG にする
2. 黒点 `LEVEL_BLACK`（既定 3%）から白点 `LEVEL_WHITE`（既定 97%）でコントラストを調整し、幅を A4 にリサイズする
3. 高さを A4 ごとに切り出す。ページ数が2以上で、最終タイルの余りが 1〜2px のときはそのタイルを捨てる
4. プリセットごとの形式で符号化し、`img2pdf` で 200dpi の PDF にする
5. ファイルサイズを検証する

A4・200dpi のピクセル数は、横 2339 x 1654、縦 1654 x 2339 です。

### コマンド

```text
./fax-pdf-gray-200dpi.sh [options] input.pdf [output.pdf]
./fax-pdf-bilevel-g4-200dpi.sh [options] input.pdf [output.pdf]
```

```text
-l, --landscape   A4横へ分割（デフォルト）
-p, --portrait    A4縦へ分割
-h, --help        ヘルプ
--                これ以降をファイル名として扱う
```

出力パスを省略したときの名前:

```text
<入力の拡張子を除いたパス>-<タグ>-a4-<landscape|portrait>.pdf
```

### 環境変数

ヘルプに出るもの:

```text
PROGRESS=0    進捗を出さない
VERBOSE=1     向き、ページサイズ、解像度、色、圧縮を出す
KEEP_TMP=1    一時ディレクトリを残し、パスを標準エラーへ出す
```

出力へ影響する上書き:

```text
RENDER_DPI=400
OUTPUT_DPI=200
LEVEL_BLACK=3
LEVEL_WHITE=97
```

### 終了コード

| コード | 意味 |
| --- | --- |
| 0 | 完了。Gray で 10 MiB を超えた場合もここ（警告は標準エラー） |
| 1 | 引数、入力、依存コマンド、ページ上限などのエラー |
| 2 | Bilevel で 1 MiB を超えた。PDFは作成済み |

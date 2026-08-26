---
name: capture
description: checklist の「UI 撮影台本」に沿って UI のスクリーンショットを撮影し、前後比較(compare.html)用の before / after 素材を保存する。「実装前の UI を撮っておいて」「after のスクショを撮って」などの依頼で発火する。
allowed-tools: Bash, Read, Glob, Grep, Write, Skill, AskUserQuestion
---

checklist の「UI 撮影台本」に沿って UI を撮影し、`/test` が生成する前後比較(compare.html)の素材を `screenshots/before/` または `screenshots/after/` に残す。

## 引数

`$ARGUMENTS` は `<issue> [side] [mode]` の形式で受け取る。

- `<issue>`: issue 番号(`123`、`#123`)または URL。空の場合はユーザーに issue 番号を質問する
- `[side]`: `before` / `after`。省略時は実装状況から推定する(`tmp/issues/<issue番号>/implementation-notes.md` または `report.md` が存在すれば `after`、無ければ `before`)。推定した場合はその旨を完了報告に明記する
- `[mode]`: `auto` / `normal`。`auto` の場合はユーザーに質問しない。省略時は質問してよい

## 前提条件

- chrome-devtools コマンドと `/chrome-devtools-cli` スキルがインストール済みであること
- `before` の場合、作業ブランチにまだ実装が入っていないこと(before は「実装前」のスナップショット)

## 手順

### 1. 既知の問題点を読み込む

`~/.agents/.skills-config/capture/config.json` を読み込み、`projects.<プロジェクト名>`(プロジェクト名は git root のディレクトリ名)に記録された過去にハマったポイント(起動待ち・認証・描画タイミングなど)を把握して撮影時に回避する。ファイルやエントリが無ければスキップして続行する。

### 2. 撮影台本の確認(自動スキップ判定)

`tmp/issues/<issue番号>/checklist.html` の「UI 撮影台本」セクションを読む。**セクションが無い、または撮影対象が 0 件の場合(UI 変更を伴わない issue)、撮影せず「スキップ(UI 変更なし)」と報告して終了する**(質問はしない。呼び出し元の `/dev` `/test` はこの報告をスキップ扱いとして処理する)。

### 3. before 固有のガード

`side = before` のとき、`implementation-notes.md` または `report.md` が既に存在する場合は実装後に呼ばれた可能性が高く before として妥当でない。`normal`: その旨を伝えて続行可否を質問する。`auto`: 撮影せず「スキップ(実装後の可能性)」と報告して終了する。

### 4. アプリの起動確認

対象アプリが起動していなければ — `normal`: ユーザーに起動を依頼する。`auto`: 既知の方法(`tmp/config.json` や上記 config.json に記録があれば)で起動を試み、できなければ「スキップ(起動不可)」と報告して終了する。

### 5. 撮影

台本の各行について `/chrome-devtools-cli` で到達手順を実行し、`tmp/issues/<issue番号>/screenshots/<side>/<撮影名>.png` に保存する。

- **撮影名は台本のものを厳守する**(`/test` が before / after をファイル名で突き合わせるため)
- `before`: 既に同名ファイルが存在する撮影名はスキップする(中断からの再開時に、実装が進んだ状態で撮り直さないため)
- `after`: 既存ファイルは上書きする(テスト失敗ループ後の再実行で最新の実装を反映するため)

### 6. ハマりポイントの記録

撮影中に発生した問題(起動待ちの不足、認証の再要求、描画前の撮影など)があれば、上記 config.json の現在プロジェクトのエントリ(無ければ作成)に `issue` / `cause` / `workaround` / `date` の形式で記録する。

## 完了報告

side・撮影した枚数・保存先・スキップした撮影名を報告する。撮影しなかった場合はスキップ理由(UI 変更なし / 実装後の可能性 / 起動不可)を明示する。side を推定した場合はその旨も添える。

## 注意事項

- コードの変更・修正は一切行わない
- 台本の到達手順どおりに操作して撮影する(独自の操作追加は前後比較のノイズになる)

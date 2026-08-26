---
name: test
description: chrome-devtools を使って動作確認チェックリストに沿ったテストを実行する。「動作確認して」「テストして」「動作テストして」「ブラウザで確認して」「チェックリストを確認して」などの依頼で発火する。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Skill, AskUserQuestion
---

chrome-devtools を使って動作確認テストを実行する。

## 引数

`$ARGUMENTS` は `<issue> [mode]` の形式で受け取る。

- `<issue>`: issue 番号(`123`、`#123`)または URL。空の場合はユーザーに issue 番号を質問する
- `[mode]`: `auto` / `normal`。`auto` の場合はユーザーに質問しない(fallback 時の挙動は手順 2 参照)。省略時は質問してよい

## 前提条件

- chrome-devtools コマンドがインストール済みであること
- `/chrome-devtools-cli` スキルがインストール済みであること

## 手順

### 1. 既知の問題点を読み込む

プロジェクト(git root)の `.agents/skills-config/test/config.json` を読み込み、過去のテストでハマったポイントを把握する。ファイルが無ければスキップして続行する。テスト実行時にこれらのポイントに注意し、同じ問題を回避する。

### 2. チェックリストの確認

`tmp/issues/<issue番号>/checklist.html` の存在を確認する。

- **存在する場合**: チェックリストの全項目を読み込み、テスト対象とする
- **存在しない場合**(fallback): チェックリストをその場で作成する。フォーマットと構成は `/plan` が生成する checklist.html の出力構造(前提条件 / 正常系 / 異常系 / エッジケース / 補助項目、AC 番号併記、checkbox)に準拠する
  - `normal`: AskUserQuestion でどのようなテストを行うか質問し、回答をもとに作成する
  - `auto`: 質問せず、`research.md` の AC と `plan.md`(あれば。md が無ければ html)から自動構築し、その旨をチェックリスト冒頭に明記する

### 3. 実装との整合確認(Deviations の反映)

`tmp/issues/<issue番号>/implementation-notes.md` が存在する場合、`## Deviations` を読み、**計画時に作られたチェックリストと実装の実態に乖離がないか**を確認する。逸脱によって操作手順・期待結果が変わった項目があれば、テスト実行前に checklist.html を更新する(変更した項目には理由を 1 行添える)。

### 4. テストの実行

チェックリストの各項目について、`/chrome-devtools-cli` スキルを使って動作確認を行う。

1. チェックリストの項目を上から順に実行する
2. 各項目について以下を行う:
   - `/chrome-devtools-cli` でブラウザ操作を行い、期待する動作を確認する
   - 操作の要所でこまめにスクリーンショットを撮影し、`tmp/issues/<issue番号>/screenshots/` 配下に保存する(ファイル名例: `01_ログイン画面.png`, `02_ボタンクリック後.png` など、連番と内容がわかる名前をつける)
   - 確認が取れた項目は `checklist.html` 内の対応する `<input type="checkbox">` に `checked` 属性を付与する(例: `<input type="checkbox" checked>`)
   - 確認に失敗した項目はチェックを入れず、失敗内容を項目要素直下に HTML で追記する(例: `<p class="ng">NG: ボタンクリック後にエラーが表示された</p>`)
3. 全項目の確認が完了したら、結果サマリーを報告する(呼び出し元が `/dev` の場合、失敗項目の有無が再計画ループの判定に使われる)

### 5. 前後比較(compare.html)の生成

checklist.html に「UI 撮影台本」セクションが無い場合(UI 変更を伴わない issue)は **このステップ全体を自動スキップ** する。

- Skill ツールで `/capture <issue> after <mode>` を実行し、台本に沿った実装後の UI を `screenshots/after/` に撮影する
- `screenshots/before/`(`/dev` が実装前に `/capture <issue> before` で撮影)と `screenshots/after/` を撮影名で突き合わせ、`tmp/issues/<issue番号>/screenshots/compare.html` を生成する
- セルフコンテインドな HTML(CSS/JS インライン)とし、画像は相対パスで参照する。撮影ペアごとにカード表示し、**横並び / スライダー** の表示切替を付ける
- before のみ存在する画面は `REMOVED`、after のみ存在する画面は `NEW` バッジ付きで単独表示する(エラーにしない)
- `screenshots/before/` が存在しない場合(実装前の `/capture` がスキップ・未実行だった場合)は after のみのギャラリーとして生成し、冒頭に before が無い旨を明記する
- 再実行(テスト失敗ループ後)では `after/` と compare.html を再生成する。**`before/` には触れない**(初回実装前のスナップショットのため)

### 6. ハマりポイントの記録

テスト中に発生した問題や予期しない挙動があった場合、上記 config.json(無ければ作成)に記録する。記録する内容:

- `issue`: 発生した問題の概要
- `cause`: 原因(判明している場合)
- `workaround`: 回避策や対処法
- `date`: 発生日

## 注意事項

- テスト実行前に必ず `config.json` の既知の問題点を確認し、同じポイントでハマらないようにする
- スクリーンショットを活用して視覚的な確認も行う(スクリーンショットは `/quiz` の解説パートでデモとしても再利用される)
- テストが全て通った場合でも、`config.json` に有用な知見があれば追記する
- 失敗した項目がある場合、原因の調査は行うがコードの修正は行わない。修正が必要な場合は呼び出し元(ユーザーまたは `/dev`)に報告する

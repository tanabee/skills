---
name: review
description: Claude Code による観点別並列コードレビュー。親で差分・コンテキストを 1 回だけ収集してディスクにキャッシュし、観点別の専任エージェント（agents/ 配下）を並列起動してレビュー、結果を統合した review.md を生成する。
allowed-tools: Bash, Read, Write, Glob, Grep, Task, AskUserQuestion
---

Claude Code で観点別に並列コードレビューを行い、結果を統合する。

**効率化の肝**: 差分取得・PR/Issue 情報収集・ローカル成果物読み込みは**親（本スキル本体）で 1 回だけ**実行し、`diff.patch` と `context.md` としてディスクに書き出す。各エージェントはこの 2 ファイルを Read するだけで共通コンテキストを得られるため、7 並列で `gh` / `git` を叩き直したり同じ成果物を読み直したりする無駄がない。

## 引数

`$ARGUMENTS` は PR 番号/URL（省略可）。`123`、`#123`、PR URL のいずれか。

## 観点エージェント一覧

各観点の専任エージェントは `agents/` に定義されている。各エージェントの出力は `review-<agent-name>.md`:

| agent-name | 観点 | 定義ファイル |
|---|---|---|
| `correctness` | 正確性 | [agents/correctness.md](./agents/correctness.md) |
| `design` | 設計 | [agents/design.md](./agents/design.md) |
| `impact` | 副作用 / 影響範囲 | [agents/impact.md](./agents/impact.md) |
| `security` | セキュリティ | [agents/security.md](./agents/security.md) |
| `performance` | パフォーマンス | [agents/performance.md](./agents/performance.md) |
| `test` | テスト | [agents/test.md](./agents/test.md) |
| `readability` | 可読性 | [agents/readability.md](./agents/readability.md) |

## 手順

### 1. 保存先ディレクトリと対象の判定

PR 番号/URL と現在の状態からレビュー対象を判定し、保存先 `<output-dir>` を決定する。

- **PR 番号・URL が指定された場合**: `gh pr view <番号>` で PR 情報を取得 → PR モード。`<output-dir> = tmp/prs/<PR 番号>`
- **PR 番号/URL が空の場合**: `gh pr view` を試み、現在のブランチに PR が存在するか確認する
  - PR が存在する → PR モード。`<output-dir> = tmp/prs/<PR 番号>`
  - PR が存在しない → ローカルモード。ユーザーに関連 issue 番号を質問し（なければスキップ可）、`<output-dir> = tmp/issues/<issue 番号>`（issue 番号が不明な場合は保存先を確認）

`mkdir -p <output-dir>` で作成する。

### 2. 差分をファイルに書き出す（1 回だけ）

親の `Bash` ツールで 1 回だけ実行し、`<output-dir>/diff.patch` に保存する:

- PR モード: `gh pr diff <PR 番号> > <output-dir>/diff.patch`
- ローカルモード: `git diff main...HEAD > <output-dir>/diff.patch`

### 3. コンテキストをファイルに書き出す（1 回だけ）

PR / Issue / ローカル成果物の情報を収集し、`<output-dir>/context.md` に親の `Write` ツールで書き出す。7 エージェントがこのファイルを Read して共通のコンテキストを得る。

収集内容:

1. **PR モードの場合**: `gh pr view` の結果から PR タイトル・説明・作成者・関連 issue を取得
2. 関連 issue があれば `gh issue view` で issue の目的・要件を取得
3. **ローカルモードの場合**: `tmp/issues/<issue 番号>/` 配下の既存成果物があれば要点を抽出
   - `plan.md` — 実装計画。意図した設計や変更方針
   - `report.md` — 実装レポート。実装者が認識している懸念点や追加変更
   - `checklist.md` — 受け入れテストチェックリスト
   - `pr.md` — PR テキスト

`context.md` のフォーマットは [assets/context-template.md](./assets/context-template.md) を参照。該当しないセクション（例: ローカルモード時の PR 情報、PR モード時のローカル成果物）は省略してよい。

### 4. 観点別レビューの並列実行

**1 メッセージ内で 7 つの Agent 呼び出しを並列発行する**（逐次呼び出ししない）。各呼び出しの `subagent_type` には上表の `agent-name`（`correctness` / `design` / `impact` / `security` / `performance` / `test` / `readability`）を指定する。

各エージェントに渡すプロンプトは共通で以下のみ（観点固有の指示はエージェント定義側にあるので本体から渡さない）:

```
## 入力ファイル
- diff-path: <output-dir 絶対パス>/diff.patch
- context-path: <output-dir 絶対パス>/context.md

## 出力先
- output-path: <output-dir 絶対パス>/review-<agent-name>.md

上記 2 つの入力ファイルを Read してから、あなたの観点でレビューを実施し、結果を output-path に Write で保存してください。
```

パスは**絶対パス**で渡す（エージェントの CWD が親と一致する保証がないため）。

### 5. 結果の統合

7 エージェント全ての完了を確認したら、各 `<output-dir>/review-<agent-name>.md` を Read し、`<output-dir>/review.md` に統合する。

統合時のルール:

- **概要**: PR / Issue の概要と変更の骨子（全観点共通）。`context.md` を参照して書く
- **良い点**: 各観点から上がった良い点を集約し重複を排除
- **指摘事項**: 重要度別（must / should / nit）にまとめる。各指摘の末尾に `[観点タグ]`（`correctness` / `design` / `impact` / `security` / `performance` / `test` / `readability`）を付与。複数観点で挙がった指摘は統合し、観点タグを複数付ける
- **まとめ**: 総合判断（マージ可否、ブロッカーの有無）

統合後の `review.md` は [template.md](./assets/template.md) の構成に従う。

### 6. ユーザーへの提示

`review.md` のサマリ（各重要度の件数、ブロッカー概要、総合判断）をユーザーに提示する。詳細は `review-<agent-name>.md` を参照するよう案内する。

`<output-dir>/diff.patch` と `<output-dir>/context.md` は中間成果物として残す（後から再確認や再実行のため）。不要なら手動で削除する。

## 注意事項

- 各エージェントは自観点のみ出力する（統合時の重複を減らすため）
- 指摘には必ず該当ファイルと行番号を含める
- 指摘ごとに重要度（must / should / nit）を付与する
- 良い点も積極的にコメントする
- 軽微なスタイルの指摘はリンターに任せ、レビューでは扱わない

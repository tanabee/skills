---
name: codex-review
description: Codex CLI にコードレビューを依頼する。PR が存在する場合は PR を、ローカルブランチの場合はメインブランチとの差分をレビューする。
allowed-tools: Bash, BashOutput, Read, AskUserQuestion
---

Codex CLI にコードレビューを依頼する。Claude Code は `codex exec` で自己完結したレビュープロンプトを渡すだけで、レビュー本体は Codex CLI 側で実施される。

## 引数

`$ARGUMENTS` は PR 番号/URL（省略可）。`123`、`#123`、PR URL のいずれか。

## 手順

### 1. Codex CLI へレビューを依頼

レビュー依頼は **同梱の sh ラッパー** `scripts/run-codex.sh` 経由で起動する。プロンプトを `Bash` 引数に直接渡すとシェルメタ文字でクォートが壊れて起動失敗するケースがあるため、**プロンプトを必ずファイルに書き出してそのパスを渡す**。ラッパー側で `--dangerously-bypass-approvals-and-sandbox` と `</dev/null` を付けて、承認プロンプトや stdin 待ちで止まらないようにする。

#### 1-1. プロンプトをファイルに書き出す

`Write` ツールで `tmp/codex-prompt-<タイムスタンプ>.txt` などの一時ファイルに以下の本文を書き出す。`<ARGS>` は `$ARGUMENTS` をそのまま展開する（空なら空文字列のまま）:

```
以下の手順でコードレビューを実施してください。

## 手順

### 1. 差分の取得
- PR 番号/URL が指定された場合: `gh pr view` で PR 情報を取得し、`gh pr diff` で差分を取得（PR モード）
- PR 番号/URL が空の場合: `gh pr view` を試み、現在のブランチに PR が存在するか確認する
  - PR が存在する → PR モードで差分を取得
  - PR が存在しない → `git diff main...HEAD` でメインブランチとの差分を取得（ローカルモード）

### 2. 情報収集
- PR モードの場合、PR の情報（タイトル、説明、関連 issue）を把握する
- 関連する issue がある場合は `gh issue view` で issue の目的・要件を把握する
- ローカルモードの場合、`tmp/issues/<issue番号>/` 配下の既存成果物を確認する:
  - `plan.html` — 実装計画。意図した設計や変更方針との整合性を確認
  - `report.html` — 実装レポート。実装者が認識している懸念点や追加変更を把握
  - `checklist.html` — 受け入れテストチェックリスト。テストの網羅性を検証する基準
  - `pr.md` — PR テキスト。PR の説明と実際の差分に乖離がないか確認

### 3. レビュー実施
変更ファイルごとにコードベースの該当箇所を読み、以下の観点でレビューする。出力フォーマットは `skills/codex-review/assets/template.html` を参照（**HTML で出力する**）:

- **正確性**: ロジックにバグや抜け漏れがないか
- **設計**: 責務分離、命名、既存パターンとの一貫性
- **副作用 / 影響範囲**: 変更・削除・リネームしたシンボル（関数・型・定数・ファイルパス・設定キー等）の参照元が壊れていないか。シグネチャ変更による型エラー、削除した機能の呼び出し元、挙動変更による既存フローへの影響を `grep` 等で網羅的に確認する
- **セキュリティ**: インジェクション、認証・認可の不備、機密情報の漏洩がないか
- **パフォーマンス**: N+1 クエリ、不要な再レンダリング、計算量の問題がないか
- **テスト**: テストの網羅性、境界値・異常系のカバレッジ
- **可読性**: 複雑すぎるロジック、不明瞭な命名、過剰な抽象化がないか

### 4. 結果の保存
- PR モード: `tmp/prs/<PR 番号>/review-codex.html`
- ローカルモード: `tmp/issues/<issue 番号>/review-codex.html`
- `mkdir -p` で出力先ディレクトリを作成してから書き込む
- 出力は `skills/codex-review/assets/template.html` のスタイルに準拠した完結した HTML ドキュメント（`<!DOCTYPE html>` から `</html>` まで）とする。重要度バッジ（must/should/nit）と観点タグの CSS クラスはテンプレートのものをそのまま利用する

## 注意事項
- 軽微なスタイルの指摘（空白、改行など）はリンターに任せ、レビューでは扱わない
- 指摘には必ず該当ファイルと行番号を含める
- 指摘ごとに重要度（must / should / nit）を付与する
- 良い点も積極的にコメントする

## 引数
<ARGS>
```

#### 1-2. sh ラッパーで `codex exec` を起動

`Bash` ツールで以下を実行する（`<prompt-file>` は 1-1 で書き出したファイルの絶対パス、`<skill-dir>` はこの skill のディレクトリの絶対パス）:

```bash
<skill-dir>/scripts/run-codex.sh <prompt-file>
```

- ラッパーは内部で `codex exec --dangerously-bypass-approvals-and-sandbox <prompt> </dev/null` を実行する
- プロンプトファイルは実行終了時にラッパーが自動削除する（呼び出し側で `rm` 不要）
- 起動はフォアグラウンド実行で構わない（Codex CLI の完了を待つだけ）

### 2. 完了検証

Codex CLI の実行完了後、`ls` で以下のいずれかが存在することを確認する:

- PR モード: `tmp/prs/<PR 番号>/review-codex.html`
- ローカルモード: `tmp/issues/<issue 番号>/review-codex.html`

ファイルが生成されていない場合は `codex exec` を再実行する（最大 2 回まで）。

### 3. ユーザーへの提示

生成された `review-codex.html` の内容を要約してユーザーに提示する。

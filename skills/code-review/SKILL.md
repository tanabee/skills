---
name: code-review
description: コードレビューを行う。PR が存在する場合は PR を、ローカルブランチの場合はメインブランチとの差分をレビューする。使用する AI CLI（claude/gemini/codex/all）を指定可能。
allowed-tools: Bash, Read, Glob, Grep, Task
context: fork
---

コードレビューを行う。

## 引数のパース

`$ARGUMENTS` は `[<モード>] [<PR 番号/URL>]` 形式。

- **モード**: `claude` | `gemini` | `codex` | `all`（省略可）
- **PR 番号/URL**: `123`、`#123`、または PR URL（省略可）

先頭トークンが `claude` / `gemini` / `codex` / `all` のいずれかならモード、それ以外は PR 番号/URL として扱う。両方とも省略可。

使用例:
- `/code-review` — 使用中の AI CLI（= Claude Code）でレビューし、ファイルに保存
- `/code-review 123` — PR #123 を使用中の AI CLI でレビューし、ファイルに保存
- `/code-review claude` — 現ブランチ/PR を Claude Code でレビューし、ファイルに保存
- `/code-review gemini 123` — PR #123 を Gemini CLI でレビュー
- `/code-review all` — Claude Code / Gemini CLI / Codex CLI の全てでレビュー

## 差分の取得

PR 番号/URL と現在の状態からレビュー対象を判定する。

- **PR 番号・URL が指定された場合**: `gh pr view` で PR 情報を取得し、`gh pr diff` で差分を取得（PR モード）
- **PR 番号/URL が空の場合**: `gh pr view` を試み、現在のブランチに PR が存在するか確認する
  - PR が存在する → PR モードで差分を取得
  - PR が存在しない → `git diff main...HEAD` でメインブランチとの差分を取得（ローカルモード）

## 情報収集

1. PR モードの場合、PR の情報（タイトル、説明、関連 issue）を把握する
2. ローカルモードの場合、ユーザーに関連する issue 番号を質問する（なければスキップ可）
3. 関連する issue がある場合は `gh issue view` で issue の目的・要件を把握する
4. ローカルモードの場合、`tmp/issues/<issue番号>/` 配下の既存成果物を確認する。存在するファイルはレビューの参考情報として活用する
   - `plan.md` — 実装計画。意図した設計や変更方針との整合性を確認する
   - `report.md` — 実装レポート。実装者が認識している懸念点や追加変更を把握する
   - `checklist.md` — 受け入れテストチェックリスト。テストの網羅性を検証する際の基準にする
   - `pr.md` — PR テキスト。PR の説明と実際の差分に乖離がないか確認する

## 出力先の決定

モード指定ありの場合、以下のパスに保存する。

- PR モード: `tmp/prs/<PR 番号>/review-<suffix>.md`
- ローカルモード: `tmp/issues/<issue 番号>/review-<suffix>.md`

`<suffix>` はモードごとに:
- `claude` → `claude-code`
- `gemini` → `gemini`
- `codex` → `codex`

ローカルモードで issue 番号が不明な場合は、ユーザーに保存先を確認する。

## レビューの実施

### モード未指定

使用中の AI でレビューを行い、結果をファイルに保存する。差分と [template.md](./assets/template.md) のフォーマットに従って出力する。
保存先の `<suffix>` は実行中の AI に対応するものを使う:
- Claude Code → `claude-code`
- Gemini CLI → `gemini`
- Codex CLI → `codex`

### `claude` モード

Claude Code 自身でレビューを行い、結果を `review-claude-code.md` に保存する。
（別途 `claude` CLI を起動する必要はない）

### `gemini` モード

Gemini CLI にモード指定なしの `/code-review` スキルを実行させる。モードを剥がした引数（PR 番号/URL のみ、空でも可）を渡す。Gemini CLI 側の「モード未指定」ブランチが `review-gemini.md` に保存するため、bash でのリダイレクトは不要。

例:
```bash
gemini -p "/code-review <PR 番号/URL>"
```

### `codex` モード

Codex CLI にモード指定なしの `/code-review` スキルを実行させる。保存は Codex CLI 側で行う。

例:
```bash
codex exec "/code-review <PR 番号/URL>"
```

### `all` モード

Claude Code / Gemini CLI / Codex CLI の 3 つでレビューを行い、それぞれ別ファイルに保存する。可能な限り並列で実行する（`gemini`/`codex` の Bash 呼び出しは `run_in_background` を活用）。

## レビュー観点

変更ファイルごとにコードベースの該当箇所を読み、以下の観点でレビューする:
- **正確性**: ロジックにバグや抜け漏れがないか
- **設計**: 責務分離、命名、既存パターンとの一貫性
- **セキュリティ**: インジェクション、認証・認可の不備、機密情報の漏洩がないか
- **パフォーマンス**: N+1 クエリ、不要な再レンダリング、計算量の問題がないか
- **テスト**: テストの網羅性、境界値・異常系のカバレッジ
- **可読性**: 複雑すぎるロジック、不明瞭な命名、過剰な抽象化がないか

## 注意事項

- 軽微なスタイルの指摘（空白、改行など）はリンターに任せ、レビューでは扱わない
- 指摘には必ず該当ファイルと行番号を含める
- 指摘ごとに重要度（must / should / nit）を付与する
- 良い点も積極的にコメントする
- ファイル保存時は出力先ディレクトリを `mkdir -p` で作成してから書き込む

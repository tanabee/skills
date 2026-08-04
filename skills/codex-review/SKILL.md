---
name: codex-review
description: Codex 公式プラグイン (codex-plugin-cc) のネイティブレビューでコードレビューを実施する。PR 番号指定時は PR を、無指定時は現在ブランチとベースブランチの差分をレビューする。
allowed-tools: Bash, Read, Write, AskUserQuestion
---

公式プラグイン `codex@openai-codex` の companion runtime(Codex ネイティブレビュー)にレビューを依頼する。レビュー本体は Codex 側で実施され、Claude Code は「対象の解決 → 実行 → 結果の HTML 整形」のみを担う。実行中のジョブは `/codex:status` で追跡できる。

## 引数

`$ARGUMENTS` は PR 番号/URL(省略可)。`123`、`#123`、PR URL のいずれか。

## 手順

### 1. レビュー対象とモードの決定

1. PR 情報の取得:
   - 引数あり: `gh pr view <引数> --json number,url,title,baseRefName,headRefName`
   - 引数なし: `gh pr view --json number,url,title,baseRefName,headRefName` で現在ブランチの PR を確認
2. モード判定:

| モード | 条件 | レビュー場所 |
|---|---|---|
| PR(カレント) | PR あり、`headRefName` == 現在ブランチ(`git rev-parse --abbrev-ref HEAD`) | 現在の作業ツリー |
| PR(worktree) | PR あり、`headRefName` != 現在ブランチ | 一時 worktree |
| ローカル | PR なし | 現在の作業ツリー |

3. ベースブランチ `<BASE>`:
   - PR モード: PR の `baseRefName`。`git fetch origin <BASE>` してから ref は `origin/<BASE>` を使う
   - ローカルモード: `tmp/config.json` の `base_branch`。無ければ `git remote show origin` の HEAD branch を検出して `tmp/config.json` に保存し、その値を使う
4. 出力先 `<output-dir>`:
   - PR モード: `tmp/prs/<PR 番号>`
   - ローカルモード: `tmp/issues/<issue 番号>`(issue 番号は現在のブランチ名 `issue-<n>` から抽出。特定できなければユーザーに保存先を確認)

### 2. レビュー実行

同梱の `scripts/run-codex-review.sh` が最新のプラグイン実体を解決して `codex-companion.mjs review` を起動する。フォアグラウンドで完了を待つ(`<skill-dir>` は本スキルのディレクトリの絶対パス)。

PR(カレント)/ローカルモード:

```bash
<skill-dir>/scripts/run-codex-review.sh --base origin/<BASE>
```

PR(worktree)モード(`<N>` は PR 番号):

```bash
git worktree add tmp/worktrees/pr-<N> --detach
git fetch origin "pull/<N>/head" "<BASE>"
git -C tmp/worktrees/pr-<N> checkout --detach FETCH_HEAD
<skill-dir>/scripts/run-codex-review.sh --cwd "<リポジトリルート絶対パス>/tmp/worktrees/pr-<N>" --base origin/<BASE>
```

- `git fetch` を 2 ref 同時に行うと `FETCH_HEAD` の先頭は `pull/<N>/head` になるためこの順で指定する。不安なら fetch を 2 回に分け、PR head の fetch を後にする
- worktree はレビュー完了後(手順 3 の HTML 出力まで終えてから)`git worktree remove --force tmp/worktrees/pr-<N>` で削除する

注意事項:

- ネイティブレビューはカスタム指示・追加観点を受け付けない。観点指定が必要な場合は本スキルではなく `/codex:adversarial-review` をユーザーに案内する
- 認証・セットアップ起因のエラーが出た場合は `/codex:setup` を案内して停止する。それ以外の失敗は 1 回だけ再実行する

### 3. 結果の HTML 整形

コマンド stdout(`# Codex Review` 以下の findings)を、`skills/codex-review/assets/template.html` のスタイルに準拠した完結 HTML(`<!DOCTYPE html>` から `</html>` まで)として `<output-dir>/review-codex.html` に書き出す。`mkdir -p` で出力先を作成してから書き込む。

- 指摘の内容・件数は Codex の出力に忠実に整形する(Claude 側で増減・改変しない)。ファイルパス・行番号は Codex 出力のまま残す
- 重要度マッピング: P0/P1/critical/high → `must`、P2/medium → `should`、P3/low/nit → `nit`(テンプレートの CSS クラスをそのまま利用)
- 観点タグ(正確性/設計/セキュリティ等)は指摘内容から Claude が付与する
- 概要セクションには PR/issue のタイトル・URL を記載する。ローカルモードで `<output-dir>/plan.md` や `report.md` があれば、変更意図を 1〜2 文で補足してよい

### 4. 完了検証とユーザーへの提示

`ls` で `<output-dir>/review-codex.html` の存在を確認する。生成されていなければ手順 2 から再実行する(最大 2 回まで)。生成後、指摘の要約(件数と must の内容)をユーザーに提示する。

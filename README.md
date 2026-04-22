# Skills

GitHub Issue 駆動開発のための Claude Code スキル集です。

## スキル一覧

| スキル | コマンド | 説明 |
|-------|---------|------|
| plan | `/plan <issue-url>` | GitHub Issue とコードベースを分析し、3つの実装アプローチを提示して詳細な計画を作成 |
| implement | `/implement <issue-url>` | 計画に基づいてコードを実装 |
| create-checklist | `/create-checklist <issue-url>` | 正常系・異常系・エッジケースを網羅した受け入れテストチェックリストを生成 |
| create-pr-text | `/create-pr-text <issue-url>` | Issue と計画から PR タイトル・説明文を作成 |
| dev | `/dev <issue-url>` | 全ワークフローを一括実行: plan → implement → create-checklist → create-pr-text |
| review | `/review <claude\|codex\|all> [PR番号\|URL]` | コードレビューを実施。PR または メインブランチとの差分を、指定した AI CLI でレビュー。モードを省略すると対話的に選択 |

## 出力

各スキルの成果物は `tmp/issues/<issue>/` に出力されます。

- `plan.md` - 実装計画
- `report.md` - 実装レポート（変更概要・懸念点・要レビュー箇所）
- `checklist.md` - 受け入れテストチェックリスト
- `pr.md` - PR タイトル・説明文

## インストール

```bash
# 全スキル
npx skills add tanabee/skills --skill '*'

# 対話的に選択
npx skills add tanabee/skills
```

---
name: retro
description: 直近の Claude Code 会話ログを分析し、CLAUDE.md / .claude/skills / .claude/rules / .claude/settings* の改善案を提案・適用するレトロスペクティブスキル。ユーザーが「retro して」「振り返りして」「最近の会話から CLAUDE.md (や skills, rules, settings) を改善して」「繰り返し指摘していることをルール化して」など、過去のやり取りをもとに設定・スキルを改善する意図を示したら必ず使用する。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion, WebFetch, WebSearch
---

直近の会話ログから「繰り返し発生している指示・訂正・手戻り・許可プロンプト」を抽出し、設定ファイルへの恒久的な改善として提案・適用する。目的は同じフィードバックを二度と繰り返させないこと。

## 手順

### 1. 実行履歴 (config.json) の読み込み

このスキルのディレクトリの `config.json` を読む。`runs` 配列の最後の `timestamp` が前回実行時刻で、これが分析範囲の起点になる。ファイルが無い・`runs` が空なら初回実行として直近 7 日を起点にする。

### 2. スコープの確認

`AskUserQuestion` (multiSelect) で改善対象を確認する: CLAUDE.md (グローバル/プロジェクト) / `.claude/skills` / `.claude/rules` / `.claude/settings*`。あわせて分析範囲 (前回実行以降で良いか) も確認する。分析中に対象外だが価値のある改善点を見つけた場合は、適用はせずレポートの「その他の提案」に含める。

### 3. 分析ソースの収集

**(a) /insights の facets キャッシュ (一次ソース)**

Claude Code 組み込みの `/insights` はセッションごとの分析結果を `~/.claude/usage-data/facets/*.json` (ファイル名 = セッション ID) にキャッシュする。各 JSON の `friction_counts` / `friction_detail` / `outcome` / `user_satisfaction_counts` / `brief_summary` は改善シグナルの宝庫なので最優先で使う。

- キャッシュが分析範囲より古い・存在しない場合は `claude -p "/insights"` で再生成する (数分かかるのでバックグラウンド実行。セッション単位でキャッシュされるため 2 回目以降は差分だけ分析される)
- facets は**全プロジェクト横断**なので、スコープが現在プロジェクトのみの場合はセッション ID を `~/.claude/projects/<プロジェクト dir>/*.jsonl` のファイル名と突き合わせて絞り込む

**(b) 会話ログ本体 (裏取り・詳細確認用)**

現在プロジェクトのログは `~/.claude/projects/<cwd の / を - に置換した名前>/` 配下の `*.jsonl` (1 ファイル = 1 セッション)。起点時刻以降に更新された (mtime) セッションを対象にし、**現在進行中のセッションは除外する**。

ログは巨大になりうるため、Read で全読みせず Python 等で必要な行だけ抽出する:

- `type == "user"` かつ `message.content` が文字列のエントリ → ユーザーの生の発言 (`timestamp` 付き)
- facets で friction が検出されたセッションは、該当箇所の前後を読み、何を恒久ルール化すれば再発を防げたかを特定する

### 4. 改善シグナルの抽出

facets の friction (`misunderstood_request` / `wrong_approach` / `buggy_code` / `excessive_changes` / `user_rejected_action` 等) とユーザー発言を時系列で読み、以下の観点で改善候補を洗い出す。

| シグナル | 改善先 |
|---|---|
| 同じ指示・訂正・好みの表明が複数セッションで繰り返される | CLAUDE.md へのルール追記 |
| スキルの不発動・誤発動、スキルの挙動への指摘 | 該当スキルの description / 本体修正 |
| 手戻り・ミスとその原因のパターン | `.claude/rules` への追加 |
| 毎回許可している定型コマンド・頻発する許可プロンプト | settings の `permissions.allow` |
| 定型の多段作業を毎回口頭で指示している | 新規スキルの提案 |

判断基準: **1 回きりの指示はノイズ、繰り返しはシグナル**。既に CLAUDE.md / rules / memory に書かれている内容の再提案はしない (適用前に既存記述を必ず確認する)。

### 5. 公式ベストプラクティスとの突き合わせ

改善候補が出揃ったら、関連する公式ドキュメント・ブログを参照して提案を裏付ける。目的は 2 つ: (a) 提案内容が公式推奨に沿っているか確認し出典を付ける、(b) ログには現れないが対象ファイルが公式推奨から明確に外れている点 (肥大化した CLAUDE.md、曖昧なスキル description 等) を発見する。

| ソース | 用途 |
|---|---|
| https://code.claude.com/docs/llms.txt | 公式ドキュメント全体の目次。ここから memory / skills / settings / hooks など該当トピックの `.md` を辿る (各ページは URL 末尾 `.md` で Markdown 取得可) |
| https://www.anthropic.com/engineering/claude-code-best-practices | CLAUDE.md・ワークフローの公式ベストプラクティス |
| https://claude.com/blog | Claude 公式ブログ。新機能の発表や活用事例。改善候補に関連する記事がないか一覧を眺める |
| WebSearch (`site:anthropic.com/engineering`, `site:claude.com/blog` 等) | 上記でカバーされない新しい公式記事の探索 |

改善候補に関連するページだけを WebFetch で読む (網羅的に読まない)。ベストプラクティス由来の提案はログ由来の提案と区別してレポートに載せ、出典 URL を根拠に含める。

### 6. HTML レポートの生成

提案を self-contained HTML (CSS インライン、ライト/ダーク両対応) としてプロジェクト root の `tmp/retro-YYYYMMDD.html` に出力し、デフォルトブラウザで開く (open スキルの開き分けと同じ)。各提案には以下を含める:

- 改善先ファイルパスと変更種別 (追記 / 修正 / 削除)
- 根拠: 該当する会話の引用 (必要最小限) と発生回数・セッション数、あれば公式ドキュメントの出典 URL
- 変更内容: 適用されるテキストを diff 風に提示
- 推奨度 (5 段階) と理由

### 7. 承認と適用

`AskUserQuestion` (multiSelect) で適用する提案を選んでもらい、**承認されたものだけ** Edit / Write で適用する。グローバル CLAUDE.md と settings* は影響が大きいので、適用後に diff を報告する。

### 8. 実行履歴の追記

適用完了後、`config.json` の `runs` 末尾にエントリを追記する。**適用ゼロでも必ず記録する** (次回実行の分析起点になるため)。現在時刻は `date -Iseconds` で取得する。

```json
{
  "timestamp": "2026-07-12T19:30:00+09:00",
  "analyzedSince": "2026-07-05T09:00:00+09:00",
  "sessionCount": 12,
  "applied": [
    { "target": "~/.claude/CLAUDE.md", "summary": "出力先を tmp/ に統一するルールを追記" }
  ]
}
```

## 注意事項

- ログには機密情報が含まれうる。レポートへの引用は改善根拠に必要な範囲に留める
- auto-memory と役割が重なる内容は、セッション横断で常に効くべきものだけを設定ファイルに昇格させる
- 提案は「なぜそうするか」が会話ログから説明できるものに限る。推測ベースの一般論は提案しない

---
name: triage
description: GitHub issue の実装難易度を tier(S / M / L / XL)として判定する。判定は Gemini Decisions API (gemini-decision-1) で行い、不通時は実行中の LLM が同じ基準で代行する。/dev がステップのモデル・effort・スキップを決めるために呼ぶ。
allowed-tools: Bash, Read, Glob, Grep, Write
---

GitHub issue ( $ARGUMENTS ) の難易度 tier を判定し、`tmp/issues/<issue番号>/triage.json` に書き出す。

本スキルは **判定のみ** を行う。tier に応じて何をスキップし、どのモデルで動かすかは呼び出し元(`/dev`)の責務。ユーザーへの質問はしない(subagent として実行されることがある)。

## 引数

`$ARGUMENTS` は `<issue> <stage>` の形式。

- `<issue>`: issue 番号(`123`、`#123`)または URL
- `<stage>`: `initial` / `confirm` / `promote`

| stage | 呼ばれる時点 | 判定材料 | 判定方法 |
|---|---|---|---|
| `initial` | /dev セットアップ直後 | issue 本文・ラベル + 軽量 grep | Gemini Decisions API (fallback: 実行中の LLM) |
| `confirm` | research 完了後 | research.md の「難易度シグナル」 | Gemini Decisions API (fallback: 実行中の LLM) |
| `promote` | plan 完了後 | plan.md の副作用 identifier 数・タスク数 | ルール(昇格のみ) |

## 基準ファイル

質問(criteria)と閾値は [assets/criteria.json](./assets/criteria.json) の 1 ファイルに集約する。人がレビュー・較正する対象はここだけ。閾値は `triage.json` の蓄積(`source` と人の上書き結果)で継続較正する前提。

## 手順

### 1. state の収集(stage ごとに必要最小限)

- `initial`:
  - `gh issue view <issue> --json title,body,labels` で title / body / labels を取得する(`gemini-decision-1` は日本語原文を高精度に扱えるため、英語要約の生成は不要)
  - 軽量 grep: issue 本文中の識別子らしい語(関数名・パス・コレクション名・画面名)を `git grep -l` で引き、ヒットしたファイル数と、書き込み系 API(`.set(` `.update(` `publish(` `emit(` `enqueue(` 等)を含むファイル数を数える。深追いしない(数十秒で終える)
  - state: `{ "title", "body", "labels", "grep": { "files_hit", "files_with_writes" } }`
- `confirm`:
  - `tmp/issues/<issue>/research.md` の `## 難易度シグナル` セクションを読み、数値を state にする
  - state: `{ "changed_files", "side_effect_identifiers", "top_candidate_gap", "unverified_assumptions", "high_impact_blind_spots", "ui_change", "ac_count" }`(research.md にある項目だけ)
  - research.md が無い場合は `initial` と同じ材料で判定し、その旨を記録する
- `promote`:
  - `tmp/issues/<issue>/plan.md` の「副作用 identifier」セクションの件数と「タスク一覧」のタスク数
  - 既存 `triage.json` の tier(無ければ M 扱い)

### 2. 判定

**`initial` / `confirm`(Gemini Decisions API)**

1. API キーを取得する: 環境変数 `GEMINI_API_KEY` があればそれを使い、未設定の場合は 1Password CLI (`op item get "dev-api-keys" --fields label=GEMINI_API_KEY --reveal`) から取得する。どちらも取得できなければ fallback へ進む
2. `criteria.json` の `model`(`gemini-decision-1`)と `questions` をそのまま入れ、手順 1 の `state` を JSON 文字列化して `input` に入れたペイロードで `POST https://generativelanguage.googleapis.com/v1beta/decisions` を curl で叩く(`x-goog-api-key: $API_KEY`、`--max-time` は `fallback.timeout_seconds`)
3. 応答の `answers.<id>.noul`(0.01〜0.99)を各 criterion のスコア、`answers.<id>.confidence`(0〜1)を確信度として取り出す
4. `thresholds` を上から評価して最初に一致した tier を採用する(どれも一致しなければ `default`)。stage が `initial` のときは `thresholds.stage_overrides.initial` の式を優先する(`initial` では `ac_is_ambiguous` 単独の XL 昇格を抑止し、局所修正の過剰な L 昇格を防ぐ)
5. **不確実帯のガード**: 一致した規則のうち、**実際に条件成立に寄与したブランチが参照する criterion のみ**について `uncertain_band`(0.4〜0.6)に入っていないか確認する(OR 条件で片方のブランチが明確に成立している場合、もう片方のブランチの値が不確実帯に入っていても棄却しない)。成立ブランチ内の criterion が不確実帯に入っていたら、その一致は採用せず `default`(M)に倒し、`uncertain: true` を記録する
6. `source: "gemini-decision"`

**fallback(実行中の LLM が代行)**

API キー無し / 非 2xx / タイムアウト / 応答の JSON 不正のとき:

1. criteria.json の各 question の `instructions` と `criteria`(`true_description` / `false_description`)を読み、**同じ state だけ**を見て、各 criterion の「yes の確率」を 0〜1 で決める。推論を長引かせず、基準に照らして機械的に付ける
2. 同じ `thresholds`(stage_overrides と成立ブランチ単位の不確実帯ガードを含む)で tier を決める
3. `source: "llm-fallback"`(Claude Code では `"claude-fallback"` も同義)、`fallback_reason` に理由(`no_api_key` / `http_<status>` / `timeout` / `bad_json`)を記録する

fallback も失敗した場合(state が集められない等)は tier を `M`、`source: "default"` とする。

**`promote`(ルール)**

criteria.json の `promote` を適用する。現在 tier より 1 段階だけ上げる(降格はしない):

- 現在 S または M で、副作用 identifier 数 ≥ `side_effect_identifiers_min_for_L` またはタスク数 ≥ `tasks_min_for_L` → 1 段階昇格
- 現在 L で、副作用 identifier 数 ≥ `side_effect_identifiers_min_for_XL` → XL
- `source: "rule"`

### 3. 書き出しと報告

`tmp/issues/<issue番号>/triage.json` に書く(既存があれば `history` に前回分を退避して上書き):

```json
{
  "issue": 123,
  "stage": "confirm",
  "tier": "L",
  "previous_tier": "M",
  "source": "gemini-decision",
  "scores": { "is_local_change": 0.12, "touches_side_effects": 0.81, "requires_design_choice": 0.34, "ac_is_ambiguous": 0.2, "has_ui_change": 0.9 },
  "confidences": { "is_local_change": 0.88, "touches_side_effects": 0.81, "requires_design_choice": 0.66, "ac_is_ambiguous": 0.8, "has_ui_change": 0.9 },
  "uncertain": false,
  "state": { "...": "判定に使った state をそのまま" },
  "criteria_file": "skills/triage/assets/criteria.json",
  "timestamp": "2026-11-22T05:20:00Z",
  "history": []
}
```

最終メッセージ(subagent のときはこれが返り値)は次の 3 行:

- `tier: <S|M|L|XL>`(promote で変化なしなら `tier: <同じ値>(変更なし)`。不確実帯で M に倒した場合は `tier: M(不確実)`)
- `source: <gemini-decision|llm-fallback|rule|default>`(fallback のときは理由も)
- 決め手になった criterion とスコア(1 行)

## 注意事項

- 検索は Grep ツールまたは `git grep` / `rg` を使う。Bash の `grep -r` / `find <dir>` は使わない(gitignore された deny ルール対象ファイルを走査して承認待ちになる)
- state には判定に必要な情報だけを入れる(無関係な情報は精度を下げる)。issue 本文が長い場合も切り詰めず、そのまま渡す
- 質問文(criteria.json)は英語のまま保つ。日本語化しない
- criteria.json の質問文と閾値を本スキル内に複製しない(定義は 1 箇所)
- `GEMINI_API_KEY`(および 1Password から取得した値)をログや成果物に絶対に書かない

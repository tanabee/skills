---
name: triage
description: GitHub issue の実装難易度を tier(S / M / L / XL)として判定する。判定は TypeSafe AI(Jev)で行い、不通時は Claude が同じ基準で代行する。/dev がステップのモデル・effort・スキップを決めるために呼ぶ。
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
| `initial` | /dev セットアップ直後 | issue 本文・ラベル + 軽量 grep | Jev(fallback: Claude) |
| `confirm` | research 完了後 | research.md の「難易度シグナル」 | Jev(fallback: Claude) |
| `promote` | plan 完了後 | plan.md の副作用 identifier 数・タスク数 | ルール(昇格のみ) |

## 基準ファイル

質問(criteria)と閾値は [assets/criteria.json](./assets/criteria.json) の 1 ファイルに集約する。人がレビュー・較正する対象はここだけ。閾値は初期値であり、`triage.json` の蓄積(`source` と人の上書き結果)で較正する前提。

## 手順

### 1. state の収集(stage ごとに必要最小限)

- `initial`:
  - `gh issue view <issue> --json title,body,labels` で title / body / labels
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

**`initial` / `confirm`(Jev)**

1. `TYPESAFE_API_KEY` を確認する。無ければ手順 3 の fallback へ
2. criteria.json の `questions` をそのまま `questions` に、手順 1 の state を `state` に入れて `POST https://api.typesafe.ai/v1/systemone` を curl で叩く(`Authorization: Bearer $TYPESAFE_API_KEY`、`model` は criteria.json の値、`--max-time` は `fallback.timeout_seconds`)
3. 応答の `answers.<id>.noul`(0〜1)を各 criterion のスコアとし、`thresholds` を上から評価して最初に一致した tier を採用(どれも一致しなければ `default`)
4. `source: "jev"`

**fallback(Claude が代行)**

API キー無し / 非 2xx / タイムアウト / 応答の JSON 不正のとき:

1. criteria.json の各 question の `instructions` と `criteria` を読み、**同じ state だけ**を見て、各 criterion の「yes の確率」を 0〜1 で決める。推論を長引かせず、基準に照らして機械的に付ける
2. 同じ `thresholds` で tier を決める
3. `source: "claude-fallback"`、`fallback_reason` に理由(`no_api_key` / `http_<status>` / `timeout` / `bad_json`)を記録する

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
  "source": "jev",
  "scores": { "is_local_change": 0.12, "touches_side_effects": 0.81, "requires_design_choice": 0.34, "ac_is_ambiguous": 0.2, "has_ui_change": 0.9 },
  "state": { "...": "判定に使った state をそのまま" },
  "criteria_file": "skills/triage/assets/criteria.json",
  "timestamp": "2026-09-20T04:00:00Z",
  "history": []
}
```

最終メッセージ(subagent のときはこれが返り値)は次の 3 行:

- `tier: <S|M|L|XL>`(promote で変化なしなら `tier: <同じ値>(変更なし)`)
- `source: <jev|claude-fallback|rule|default>`(fallback のときは理由も)
- 決め手になった criterion とスコア(1 行)

## 注意事項

- 検索は Grep ツールまたは `git grep` / `rg` を使う。Bash の `grep -r` / `find <dir>` は使わない(gitignore された deny ルール対象ファイルを走査して承認待ちになる)
- state には判定に必要な情報だけを入れる(無関係な情報は精度を下げる)。issue 本文が長い場合も切り詰めず、そのまま渡す
- criteria.json の質問文と閾値を本スキル内に複製しない(定義は 1 箇所)
- `TYPESAFE_API_KEY` の値をログや成果物に書かない

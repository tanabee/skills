---
name: dev
description: GitHub issue から計画・実装・テスト・レビュー・PR テキスト・理解確認まで一気通貫で行う。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
disable-model-invocation: true
---

GitHub issue ( $ARGUMENTS ) に対して、計画から PR テキスト作成・理解確認まで一気通貫で実行する。

## 引数

`$ARGUMENTS` は `<issue> [mode]` の形式で受け取る。

- `<issue>`: issue 番号(`123`、`#123`)または URL。必須。空の場合はユーザーに issue 番号を質問する。URL が渡された場合は issue 番号を抽出し、以降のステップには正規化済みの issue 番号(例: `123`)を渡す。
- `[mode]`: 慎重度合い。`auto` / `normal` のいずれか。省略可(開始時セットアップで質問する)。

## ステップ定義表

**本スキルにおけるステップの唯一の定義**。チェックポイント選択・スキップ選択・タスク登録・実行手順はすべてこの表を参照する。ステップを増減する場合はこの表の修正だけで完結させること。

| # | ステップ | 実行形態 | 呼び出し | 主な成果物 | 前提成果物 | 並列 |
|---|---|---|---|---|---|---|
| 1 | research | inline | Skill `/research <issue> <mode>` | research.md/.html | — | — |
| 2 | plan | inline | Skill `/plan <issue> <mode>` | plan.md/.html, checklist.html | research.md | — |
| 3 | review-plan | subagent | Agent → `/review-plan <issue>` | review-plan.md/.html | plan.md, checklist.html | — |
| 4 | implement | inline | Skill `/implement <issue> <mode>` | コード, implementation-notes.md, report.md/.html | plan.md | — |
| 5 | create-pr-text | subagent | Agent → `/create-pr-text <issue>` | pr.md | plan.md, report.md | A |
| 6 | test | inline | Skill `/test <issue> <mode>` | checklist.html 更新, screenshots/ | checklist.html, implementation-notes.md | A |
| 7 | review | inline | Skill `/review <issue>` | review.md/.html | 実装済みコード | — |
| 8 | quiz | subagent | Agent → `/quiz <issue>` | quiz.html | report.md, review.md | B |
| 9 | notify-discord | inline | Skill `/notify-discord <サマリ>` | — | — | B |

- 成果物はすべて `tmp/issues/<issue番号>/` 配下
- **成果物の 2 種生成(md/.html)**: research / plan / report / review-plan / review は **md(正・スキル間の伝達用)と html(人間レビュー用ビュー)** の 2 種で生成される。スキルは md を読み、無ければ html にフォールバックする。checklist.html は `/test` が結果を書き込む状態ファイルのため html 単一
- **実行形態**
  - `inline`: Skill ツールで本会話内で実行する。ユーザーとの対話・コード変更・ブラウザ操作を伴うステップ
  - `subagent`: Agent ツール(`general-purpose`)で別コンテキストとして実行する。対話が不要で「成果物を書いて要約を返す」ステップ。メイン会話のコンテキスト消費を抑え、review-plan では **plan 作成の文脈を持たない独立視点** も担保する
- **並列**: 同じグループ記号のステップは同時に実行する(「並列グループの実行」参照)

## 開始時セットアップ

以下を **1 回の AskUserQuestion にまとめて** 質問する(mode が引数で指定済みならその質問は省く)。このセットアップ質問は mode の「質問しない」制約の**適用対象外**(mode 確定前のセットアップであるため)。

1. **mode**: `auto` / `normal`(推奨: `normal`)
2. **チェックポイント**(multiSelect): ステップ 1〜8 のうち「完了後に停止して内容を確認したいステップ」を 0 個以上(デフォルト: なし)
3. **スキップ**(multiSelect): ステップ 1〜9 のうち「実行しないステップ」を 0 個以上(デフォルト: なし)

### mode の挙動

| mode | 挙動 |
| --- | --- |
| `auto` | パイプライン中はユーザーに質問しない。plan の方針選択・曖昧な要件・config 追記もすべて推奨案で自動決定し、**置いた仮定は各成果物に明記させる** |
| `normal` | plan の方針選択と config 追記の承認のみ質問する。それ以外は中断せず進める |

- mode は inline ステップの**呼び出し引数として明示的に渡す**(例: `/plan 123 auto`)。サブスキル側の質問要否は渡された mode に従う
- subagent ステップは設計上ユーザーへ質問できないため mode に依存しない(質問が発生しない作りのステップのみを subagent にしている)
- チェックポイント停止・ループ上限到達時の報告は mode に関わらず必ず行う

## 状態の永続化(dev-state.json)

セットアップ完了時に `tmp/issues/<issue番号>/dev-state.json` を書き出し、ステップの開始・完了・ループ突入のたびに更新する。コンテキスト圧縮や中断を跨いでも選択と進捗を復元するため。

```json
{
  "issue": 123,
  "mode": "normal",
  "checkpoints": ["plan", "review"],
  "skips": [],
  "loops": { "review_plan": 0, "test": 0, "review": 0 },
  "steps": { "research": "completed", "plan": "in_progress" }
}
```

`/dev` 開始時に同 issue の dev-state.json が既に存在する場合は内容を読み、未完了の最初のステップからの再開をユーザーに提案する(auto では自動で再開する)。

## 作業ブランチの準備

セットアップ完了後、TaskCreate より前に実行する。実装コミットがベースブランチや無関係なブランチに混ざるのを防ぐガード。

1. **ベースブランチの確定**: `tmp/config.json` の `base_branch` を読む。無ければ `git remote show origin` の HEAD branch から検出し、`tmp/config.json` に保存する(以降 `<base>` と表記)
2. `git rev-parse --abbrev-ref HEAD` で現在のブランチ名を取得する。期待するブランチ名は **`issue-<issue番号>`**
3. 比較して分岐:
   - **一致**: そのまま進む
   - **不一致**: `git rev-parse --verify issue-<issue番号>` で存在確認し、存在すれば checkout、存在しなければ以下を順に実行
     1. `git status --porcelain` で未コミットの変更を確認。**変更がある場合は中断してユーザーに対処を促す**(自動 stash / commit / discard はしない)
     2. `git fetch origin <base>`
     3. `git checkout -b issue-<issue番号> origin/<base>`(ローカル `<base>` を経由しない)
4. 既存のブランチ名規約が `issue-<issue番号>` と異なるプロジェクトでは、動作を変える前にユーザーに相談する

## タスク管理

セットアップ後、ステップ定義表の各ステップ(スキップ対象を除く)を TaskCreate で一括登録する。

- 各ステップの開始直前に `in_progress`、正常完了で即座に `completed` に更新する(バッチ更新しない)
- 同時に `in_progress` にできるのは原則 1 タスク。**例外: 同じ並列グループのステップは同時に `in_progress` にしてよい**
- ループ突入時は既存タスクを `in_progress` のまま保ち、必要ならループ内サブタスク(例: `replan-round-2`)を追加する
- 上限到達などで失敗終了する場合は、残タスクを削除して dev-state.json に理由を記録し、ユーザーに報告する

## 実行手順

ステップ定義表の順に実行する。各ステップで:

1. **スキップ判定**: スキップ指定されていれば Skill / Agent 呼び出しを行わず次のステップへ
2. **前提成果物の確認**: 表の「前提成果物」が存在するか確認する。存在しない場合(スキップや前回実行の欠如による):
   - サブスキル側に fallback があればそれに委ねる
   - fallback が無い場合 — `auto`: 警告を dev-state.json に記録し、続行可能なら続行、不可能ならそのステップもスキップ扱いにする。`normal`: ユーザーに続行可否を確認する
3. **実行**: 実行形態に従って呼び出す(inline = Skill ツール + mode 引数、subagent = Agent ツール。後述)
4. **チェックポイント判定**: 指定されていれば停止する(「チェックポイント停止の挙動」参照)

### subagent への依頼形式

Agent ツール(`subagent_type: general-purpose`)で起動し、プロンプトに以下を含める:

- Skill ツールで対象スキルを実行すること(例: `Skill ツールで review-plan を args「123」で実行してください`)
- リポジトリルートと成果物ディレクトリ(`tmp/issues/<issue番号>/`)の**絶対パス**
- 「ユーザーへの質問はできない。判断に迷う場合は保守的に倒し、その旨を成果物に明記する」という制約
- 最終メッセージで返すサマリの形式:
  - review-plan: 判定(OK / 差し戻し)、must / should / OK の件数、must の要旨(1 行ずつ)
  - create-pr-text / quiz: 生成した成果物のパスと要点

### 並列グループの実行

- **グループ A(create-pr-text ∥ test)**: create-pr-text の subagent を background で起動した**直後に** test を inline で実行する。両方の完了を確認してから review へ進む
- **グループ B(quiz ∥ notify-discord)**: quiz の subagent を background で起動した直後に notify-discord を inline で実行する。両方の完了を確認してから `/dev` を終了する
- グループ内のステップに**チェックポイントが指定されている場合、そのグループは表の順の直列実行に落とす**(停止位置を明確にするため)
- グループ内の片方がスキップされた場合、残りを単独で通常実行する

### notify-discord への引数

dev が実施内容のサマリを組み立てて `/notify-discord <サマリ>` として渡す。**pitch の要領**(結論・成果を先頭に、続けて要点)で構成する: 何ができたか(1-2 行)→ テスト・レビュー結果の要点 → 実施ステップ → 主要成果物のパス(詳細な解説は quiz.html の解説パートを案内)。notify-discord 側からユーザーへの質問が発生しない状態で呼び出すこと。

## ループ(3 種)と上限

| ループ | 発動条件 | 戻り先 | 上限 |
|---|---|---|---|
| review-plan 差し戻し | 修正必須(must)が 1 件以上 | plan(修正)→ review-plan 再実行 | 3 回 |
| test 失敗 | チェックリストに失敗項目 | plan(更新)→ review-plan → implement → …(表の順に再実行) | test 実行 3 回 |
| review 差し戻し | must 指摘が 1 件以上 | implement(指摘の修正)→ review 再実行 | review 実行 3 回 |

- 各ループは**独立にカウント**し、dev-state.json の `loops` に記録する
- 再計画・修正時は `tmp/issues/<issue番号>/` の既存成果物を新規作成し直すのではなく、失敗・指摘内容を反映して**更新**する
- **review ループで実装が変わった場合は pr.md も更新する**(create-pr-text を subagent で再実行)
- 上限に達しても解消しない場合はループを終了し、状況をユーザーに報告して判断を仰ぐ(**auto でもここは停止する**)
- ループ再突入時の確認頻度は mode に従う(auto: 確認なし、normal: 再計画時の方針選択のみ)

## 完了の定義(DoD)ゲート

review ループを抜けたら、グループ B に進む前に plan.md の「完了の定義(Definition of Done)」を読み、各項目の充足を検証する。

- 各項目を**証跡に基づいて**判定する(例: checklist.html の全項目が checked / review.md の must が 0 / lint・type check が pass / 必要なドキュメント更新済み)
- 判定結果を dev-state.json に記録する
- **未充足項目がある場合**: 対応するループ(test / review)または implement に戻る。該当ループが上限到達済みならユーザーに報告して判断を仰ぐ
- 全項目充足でグループ B へ進む

## チェックポイント停止の挙動

指定されたステップの完了後、進行を一時停止し、直前ステップの成果物パスと次に実行されるステップを提示した上で AskUserQuestion で選択してもらう:

- **続行**: 次のステップに進む
- **中断**: `/dev` を終了する(残タスクは削除し、dev-state.json に記録)
- **前のステップを再実行**: 直前のステップを更新モードでやり直す(再実行後、同じチェックポイントで再度停止する)

ユーザーが回答するまで次のステップに進まない。

## config への学習機構(手戻りを防御に変換する)

以下のいずれかで、plan が見落としていた**間接依存・暗黙の必須セット・カスケード**が判明した場合、今後の `/plan` と `/review-plan` で防げるよう、両スキルの `config.json` の `attentions` 配列に追記する(完全重複運用)。

1. **implement 完了時**: implementation-notes.md の「Deviations」に記録された逸脱(**手戻りが起きる前の一次情報**。最速の学習源として implement 完了ごとに必ず確認する)
2. **test 失敗時**: 失敗原因の分析結果
3. **review 指摘時**: must / should の指摘内容

### 追記の判断基準

以下のいずれかに該当する場合、追記候補とする:

- 「コードに直接現れない依存」だった(trigger / subscriber / 設定 / 暗黙の必須セット等)
- プロジェクト固有のフレームワーク慣習が原因だった(特定のディレクトリにある自動登録など)
- 同種の手戻りが今後別 issue でも起きうる汎用的な内容である

逆に、以下は追記しない: その issue 限りの個別事情 / コード grep で素直に辿れる直接依存 / 既に同等の内容が `attentions` に存在する。

### フォーマットと mode ごとの挙動

`attentions` には自然言語 1 行(または短い段落)で記述する。例:

```
"Firestore `orders/{orderId}` への書き込みは functions/src/triggers/onOrderWrite.ts を発火し、Discord 通知文面の更新も必要"
```

- `auto`: ユーザー確認なしで両 config に自動追記
- `normal`: 追記候補の内容と追記先を提示し、承認されれば追記

## 注意事項

- mode に応じた質問頻度を守る。セットアップ質問・チェックポイント停止・ループ上限到達時の報告・DoD 未充足かつループ上限到達時の報告は mode の適用対象外(必ず行う)
- ステップの増減・並列グループの変更はステップ定義表の修正だけで完結させる
- サブスキル間の成果物規約(必須セクション・フォーマット)は各サブスキルの SKILL.md が定義する。dev は **成果物パスの受け渡し・実行順序・ループ・状態管理** にのみ責務を持つ
- subagent の結果が返らない・失敗した場合は 1 回だけ再実行し、それでも失敗したら inline 実行に切り替える

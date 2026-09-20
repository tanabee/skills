---
name: dev
description: GitHub issue から計画・実装・テスト・レビュー・PR テキスト・理解確認まで一気通貫で行う。難易度 tier に応じてステップのモデル・effort・スキップを切り替える。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
disable-model-invocation: true
---

GitHub issue ( $ARGUMENTS ) に対して、計画から PR テキスト作成・理解確認まで一気通貫で実行する。

## 引数

`$ARGUMENTS` は `<issue> [mode] [tier]` の形式で受け取る。

- `<issue>`: issue 番号(`123`、`#123`)または URL。必須。空の場合はユーザーに issue 番号を質問する。URL が渡された場合は issue 番号を抽出し、以降のステップには正規化済みの issue 番号(例: `123`)を渡す
- `[mode]`: 慎重度合い。`auto` / `normal`。省略可(開始時セットアップで質問する)
- `[tier]`: 難易度。`S` / `M` / `L` / `XL` / `fixed:<model>[/<effort>]` / `full`。省略時は `/triage` が判定する。指定時は triage を一切呼ばない
  - `fixed:<model>[/<effort>]`: tier 判定もスキップもせず、**全ステップを指定した model / effort で実行する**(例: `fixed:opus/high`、`fixed:opus`)。`full` は `fixed:fable/xhigh` の別名

## ステップ定義表

**本スキルにおけるステップの唯一の定義**。チェックポイント選択・タスク登録・実行手順はすべてこの表と次の「実行形態表」を参照する。ステップを増減する場合はこの 2 表の修正だけで完結させること。

| # | ステップ | 呼び出し | 主な成果物 | 前提成果物 | 並列 |
|---|---|---|---|---|---|
| 1 | triage-initial | `/triage <issue> initial` | triage.json | — | — |
| 2 | research | `/research <issue> <mode> <tier>` | research.md/.html | — | — |
| 3 | triage-confirm | `/triage <issue> confirm` | triage.json | research.md | — |
| 4 | plan | `/plan <issue> <mode>`(S は `/plan <issue> <mode> lite`) | plan.md/.html, checklist.html | research.md(S は不要) | — |
| 5 | triage-promote | `/triage <issue> promote` | triage.json | plan.md | — |
| 6 | review-plan | `/review-plan <issue>` | review-plan.md/.html | plan.md, checklist.html | — |
| 7 | capture-before | `/capture <issue> before auto` | screenshots/before/ | checklist.html | — |
| 8 | implement | `/implement <issue> <mode>` | コード, implementation-notes.md, report.md/.html | plan.md | — |
| 9 | create-pr-text | `/create-pr-text <issue>` | pr.md | plan.md, report.md | A |
| 10 | test | `/test <issue> <mode>` | checklist.html 更新, screenshots/after/, compare.html | checklist.html, implementation-notes.md | A |
| 11 | review | `/review <issue> <tier>` | review.md/.html | 実装済みコード | — |
| 12 | quiz | `/quiz <issue>` | quiz.html | report.md, review.md | B |
| 13 | notify-discord | `/notify-discord <サマリ>` | — | — | B |

- 成果物はすべて `tmp/issues/<issue番号>/` 配下
- **成果物の 2 種生成(md/.html)**: research / plan / report / review-plan / review は md(正・スキル間の伝達用)と html(人間レビュー用ビュー)の 2 種。スキルは md を読み、無ければ html にフォールバックする。checklist.html は `/test` が結果を書き込む状態ファイルのため html 単一
- **capture-before の自動スキップ**: UI 変更を伴わない issue(checklist.html に「UI 撮影台本」が無い等)では、スキル側が撮影せずスキップを報告する。dev はこの報告を受けたらスキップ扱いとして dev-state.json に記録し、次へ進む

### 実行形態表(tier × ステップ)

値は `inline`(Skill ツールで本会話内で実行。セッションモデルで動く)/ `agent:<model>`(Agent ツールで別コンテキストとして実行し、その model を渡す)/ `skip`。

| ステップ | S | M | L | XL | fixed:\<model\> |
|---|---|---|---|---|---|
| triage-initial | agent:opus(tier 引数指定時は skip) | ← | ← | ← | skip |
| research | skip | inline | inline | inline | inline |
| triage-confirm | skip | agent:opus | agent:opus | agent:opus | skip |
| plan | inline(lite) | inline | inline | inline | inline |
| triage-promote | skip | agent:opus | agent:opus | agent:opus | skip |
| review-plan | skip | agent:opus ※1 | agent:opus | agent:fable | agent:\<model\> |
| capture-before | skip | agent:opus | agent:opus | agent:opus | agent:\<model\> |
| implement | inline | inline | inline | inline | inline |
| create-pr-text | agent:opus | agent:opus | agent:opus | agent:opus | agent:\<model\> |
| test | agent:opus ※2 | agent:opus ※2 | agent:opus ※2 | agent:opus ※2 | ※2 |
| review | agent:opus | agent:opus | agent:opus | agent:opus | agent:\<model\> |
| quiz | skip | agent:opus | agent:opus | agent:opus | agent:\<model\> |
| notify-discord | agent:opus | agent:opus | agent:opus | agent:opus | agent:\<model\> |

- triage-initial は tier が未確定の時点で実行するため、tier 引数が無い限り常に agent:opus
- ※1 M の review-plan は、plan.md の「副作用 identifier」セクションが空 **かつ** `.agents/skills-config/review-plan/config.json` の `attentions` に plan の変更対象へ該当する項目が無い場合、dev が自動スキップしてよい(dev-state.json に理由を記録)
- ※2 test は `mode=auto` のとき agent(subagent は質問できないため、質問しない auto だけ切り出せる)。`mode=normal` では inline(アプリ起動依頼・checklist 無し fallback で質問が発生しうる)。fixed では auto なら agent:\<model\>、normal なら inline
- **inline ステップのモデルと effort はセッション設定に従う**(Claude 側からは変更できない)。tier 確定時に次の推奨値を提示する: S → `/model opus` + `/effort medium`(任意)/ M → `/effort high` / L・XL → `/effort xhigh` / fixed → `/model <model>` + `/effort <effort>`。人が設定した前提で進め、案内した値を dev-state.json に記録する
- review 内の Claude レビュアー Agent の model は review スキルが tier 引数から決める(S/M: opus、L/XL: fable、fixed: \<model\>)。research 内のファンアウト Agent は research スキルが tier 引数から決める(既定 opus、fixed: \<model\>)
- 線引きの原則: **判断が後段にカスケードするステップ(research 本体・plan・implement・L 以上のレビュアー)だけ Fable(セッションモデル)に残し、作業・診断寄りのステップは Opus の subagent に落とす**。Sonnet / Haiku は精度リスクを取ってまで使わず、安くしたければ Opus の effort を下げる

## 開始時セットアップ

以下を **1 回の AskUserQuestion にまとめて** 質問する(mode が引数で指定済みならその質問は省く)。このセットアップ質問は mode の「質問しない」制約の適用対象外。

1. **mode**: `auto` / `normal`(推奨: `normal`)
2. **チェックポイント**(multiSelect): triage 以外のステップ 2〜12 のうち「完了後に停止して内容を確認したいステップ」を 0 個以上(デフォルト: なし)

スキップするステップは tier から決まるため、個別に質問しない。特定ステップを飛ばしたい場合は tier 引数で調整する(例: research を飛ばすなら `S`)。

## tier の確定と反映

1. tier 引数が指定されていればそれを採用し、`tier_source: "user"` とする。triage は呼ばない
2. 指定が無ければ、セットアップ直後に `triage-initial` を実行して仮 tier を得る(S の見極めが目的。迷えば M になる)
3. research 完了後に `triage-confirm` で確定する。**以降のステップの実行形態・スキップ・推奨 effort はこの結果で決める**
4. plan 完了後に `triage-promote` を実行し、昇格があれば以降に反映する(降格はしない)
5. tier が確定・変化するたびに dev-state.json の `tier` / `tier_source` を更新し、`normal` モードでは確定時に 1 回だけ「tier と推奨 `/effort`」を提示して続行可否を確認する(`auto` は提示のみで続行)。triage が `source: default`(Jev も fallback も失敗)を返した場合は mode に関わらず確認する

## 状態の永続化(dev-state.json)

セットアップ完了時に `tmp/issues/<issue番号>/dev-state.json` を書き出し、ステップの開始・完了・ループ突入・tier 変更のたびに更新する。

```json
{
  "issue": 123,
  "mode": "normal",
  "tier": "M",
  "tier_source": "jev",
  "fixed": null,
  "checkpoints": ["plan", "review"],
  "skips": ["quiz"],
  "effort_advised": "high",
  "loops": { "review_plan": 0, "test": 0, "review": 0 },
  "steps": { "triage-initial": "completed", "research": "in_progress" }
}
```

- `skips` は tier から導出した結果(自動スキップ含む)の記録。人が選ぶ項目ではない
- `fixed` は `fixed:` 指定時のみ `{ "model": "opus", "effort": "high" }`
- `/dev` 開始時に同 issue の dev-state.json が既に存在する場合は内容を読み、未完了の最初のステップからの再開をユーザーに提案する(auto では自動で再開)。tier は記録済みの値を使う

## 作業ブランチの準備

セットアップ完了後、TaskCreate より前に実行する。実装コミットがベースブランチや無関係なブランチに混ざるのを防ぐガード。

1. **ベースブランチの確定**: `tmp/config.json` の `base_branch` を読む。無ければ `git remote show origin` の HEAD branch から検出し、`tmp/config.json` に保存する(以降 `<base>`)
2. `git rev-parse --abbrev-ref HEAD` で現在のブランチ名を取得する。期待するブランチ名は **`issue-<issue番号>`**
3. 比較して分岐:
   - **一致**: そのまま進む
   - **不一致**: `git rev-parse --verify issue-<issue番号>` で存在確認し、存在すれば checkout、存在しなければ以下を順に実行
     1. `git status --porcelain` で未コミットの変更を確認。**変更がある場合は中断してユーザーに対処を促す**(自動 stash / commit / discard はしない)
     2. `git fetch origin <base>`
     3. `git checkout -b issue-<issue番号> origin/<base>`(ローカル `<base>` を経由しない)
4. 既存のブランチ名規約が `issue-<issue番号>` と異なるプロジェクトでは、動作を変える前にユーザーに相談する

## タスク管理

tier 確定後(tier 引数指定時はセットアップ直後、それ以外は triage-initial 直後)、ステップ定義表の各ステップ(実行形態表で skip のものを除く)を TaskCreate で一括登録する。triage-confirm で tier が変わりスキップ集合が変わった場合はタスクを追加・削除して同期する。

- 各ステップの開始直前に `in_progress`、正常完了で即座に `completed` に更新する(バッチ更新しない)
- 同時に `in_progress` にできるのは原則 1 タスク。**例外: 同じ並列グループのステップは同時に `in_progress` にしてよい**
- ループ突入時は既存タスクを `in_progress` のまま保ち、必要ならループ内サブタスク(例: `replan-round-2`)を追加する
- 上限到達などで失敗終了する場合は、残タスクを削除して dev-state.json に理由を記録し、ユーザーに報告する

## 実行手順

ステップ定義表の順に実行する。各ステップで:

1. **スキップ判定**: 実行形態表で skip(自動スキップ条件を含む)なら呼び出しを行わず、dev-state.json の `skips` に記録して次へ
2. **前提成果物の確認**: 表の「前提成果物」が存在するか確認する。存在しない場合(スキップや前回実行の欠如による):
   - サブスキル側に fallback があればそれに委ねる
   - fallback が無い場合 — `auto`: 警告を dev-state.json に記録し、続行可能なら続行、不可能ならそのステップもスキップ扱いにする。`normal`: ユーザーに続行可否を確認する
3. **実行**: 実行形態表に従って呼び出す(inline = Skill ツール + 引数、agent = Agent ツールに model を渡す。後述)
4. **HTML 成果物のオープン**: そのステップが生成・更新した `.html` のうち、表の「主な成果物」に挙げたものだけを Skill ツールで `/open <絶対パス>` を呼んで開く(review の `review-claude.html` / `review-codex.html` / `context.html` のような中間成果物は開かない)。agent ステップの成果物も完了確認後に dev 側で開く。ループでの再生成・更新時も毎回開き直す
5. **チェックポイント判定**: 指定されていれば停止する(「チェックポイント停止の挙動」参照)

### mode の挙動

| mode | 挙動 |
| --- | --- |
| `auto` | パイプライン中はユーザーに質問しない。plan の方針選択・曖昧な要件・config 追記もすべて推奨案で自動決定し、**置いた仮定は各成果物に明記させる** |
| `normal` | plan の方針選択・config 追記の承認・tier 確定時の確認のみ質問する。それ以外は中断せず進める |

- mode は inline ステップの呼び出し引数として明示的に渡す(例: `/plan 123 auto`)
- agent ステップは設計上ユーザーへ質問できないため、質問が発生しない引数(`auto` 相当)で起動する
- チェックポイント停止・ループ上限到達時の報告は mode に関わらず必ず行う

### agent ステップの依頼形式

Agent ツール(`subagent_type: general-purpose`、**`model` に実行形態表の値**)で起動し、プロンプトに以下を含める:

- Skill ツールで対象スキルを実行すること(例: `Skill ツールで review-plan を args「123」で実行してください`)。呼び出し引数はステップ定義表のとおり(mode を取るスキルには `auto` を渡す)
- リポジトリルートと成果物ディレクトリ(`tmp/issues/<issue番号>/`)の**絶対パス**
- 「ユーザーへの質問はできない。判断に迷う場合は保守的に倒し、その旨を成果物に明記する」という制約
- 「検索は Grep ツールまたは `git grep` / `rg` を使い、Bash の `grep -r` / `find <dir>` は使わない(gitignore された `.secret.local` 等の deny ルール対象ファイルを走査して承認待ちになる)」という制約
- 最終メッセージで返すサマリの形式:
  - triage: tier / source / 決め手(3 行)
  - review-plan: 判定(OK / 差し戻し)、must / should / OK の件数、must の要旨(1 行ずつ)
  - review: must / should / nit の件数、両者一致の件数、ブロッカー概要、総合判断
  - test: 失敗項目の有無と件数、compare.html の有無
  - capture / create-pr-text / quiz / notify-discord: 生成した成果物のパスと要点(capture はスキップ理由があればそれ)

### 並列グループの実行

- **グループ A(create-pr-text ∥ test)**: create-pr-text の subagent を background で起動した**直後に** test を実行する(test が agent の場合も同一メッセージで並列起動してよい)。両方の完了を確認してから review へ進む
- **グループ B(quiz ∥ notify-discord)**: quiz の subagent を background で起動した直後に notify-discord を実行する。両方の完了を確認してから `/dev` を終了する
- グループ内のステップに**チェックポイントが指定されている場合、そのグループは表の順の直列実行に落とす**
- グループ内の片方がスキップされた場合、残りを単独で通常実行する

### notify-discord への引数

dev が実施内容のサマリを組み立てて `/notify-discord <サマリ>` として渡す。**pitch の要領**(結論・成果を先頭に、続けて要点)で構成する: 何ができたか(1-2 行)→ tier と使ったモデル → テスト・レビュー結果の要点 → 実施ステップ → 主要成果物のパス(詳細な解説は quiz.html の解説パートを案内)。notify-discord 側からユーザーへの質問が発生しない状態で呼び出すこと(`webhook_url` 未設定なら dev が事前に検出し、そのステップだけ inline で実行する)。

## ループ(3 種)と上限

| ループ | 発動条件 | 戻り先 | 上限(S) | 上限(M 以上・fixed) |
|---|---|---|---|---|
| review-plan 差し戻し | 修正必須(must)が 1 件以上 | plan(修正)→ review-plan 再実行 | —(S は review-plan なし) | 3 回 |
| test 失敗 | チェックリストに失敗項目 | plan(更新)→ review-plan → implement → …(表の順に再実行。**capture-before と triage は除く**) | test 実行 1 回 | test 実行 3 回 |
| review 差し戻し | must 指摘が 1 件以上 | implement(指摘の修正)→ review 再実行 | review 実行 2 回 | review 実行 3 回 |

- 各ループは**独立にカウント**し、dev-state.json の `loops` に記録する
- **S で上限に達した場合は tier 判定の誤りとみなし、tier を M に昇格して(`tier_source: "loop-promote"`)残りのステップを M として続行する**(research は飛ばしたまま。review-plan と quiz は以降有効になる)。M 以上で上限に達しても解消しない場合はループを終了し、状況をユーザーに報告して判断を仰ぐ(**auto でもここは停止する**)
- 再計画・修正時は `tmp/issues/<issue番号>/` の既存成果物を新規作成し直すのではなく、失敗・指摘内容を反映して**更新**する
- **review ループで実装が変わった場合は pr.md も更新する**(create-pr-text を agent で再実行)
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

以下のいずれかで、plan が見落としていた**間接依存・暗黙の必須セット・カスケード**が判明した場合、今後の `/plan` と `/review-plan` で防げるよう、プロジェクト(git root)の `.agents/skills-config/plan/config.json` と `.agents/skills-config/review-plan/config.json` の `attentions` 配列(ファイルが無ければ作成)に追記する(完全重複運用)。

1. **implement 完了時**: implementation-notes.md の「Deviations」に記録された逸脱(手戻りが起きる前の一次情報。implement 完了ごとに必ず確認する)
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

- mode に応じた質問頻度を守る。セットアップ質問・tier 確定時の確認(normal)・チェックポイント停止・ループ上限到達時の報告・DoD 未充足かつループ上限到達時の報告は mode の適用対象外(必ず行う)
- ステップの増減・並列グループ・実行形態の変更はステップ定義表と実行形態表の修正だけで完結させる。**サブスキルの SKILL.md に model / effort を書かない**(frontmatter の model 上書きは静的で、そのターンの残り全体に残るため fixed と両立しない)
- サブスキル間の成果物規約(必須セクション・フォーマット)は各サブスキルの SKILL.md が定義する。dev は **成果物パスの受け渡し・実行順序・実行形態(model)・HTML 成果物のオープン・ループ・状態管理** にのみ責務を持つ
- subagent の結果が返らない・失敗した場合は 1 回だけ再実行し、それでも失敗したら inline 実行に切り替える(Fable で動くことになるが、止まるよりよい)

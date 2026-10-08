---
name: dev
description: GitHub issue から計画・実装・テスト・レビュー・PR テキスト・理解確認まで一気通貫で行う。難易度 tier に応じてステップのモデル・effort・スキップを切り替える。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent, SendMessage, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
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
| 8 | implement | `/implement <issue> <mode>`(ループからの再実行は `… <mode> fix`) | コード, implementation-notes.md, report.md/.html | plan.md | — |
| 9 | create-pr-text | `/create-pr-text <issue>` | pr.md | plan.md, report.md | A |
| 10 | test | `/test <issue> <mode>` | checklist.html 更新, screenshots/after/, compare.html | checklist.html, implementation-notes.md | A |
| 11 | review | `/review <issue> <tier>` | review.md/.html | 実装済みコード | — |
| 12 | quiz | `/quiz <issue>` | quiz.html | report.md, review.md | B |
| 13 | notify-discord | `/notify-discord <サマリ>` | — | — | B |

- 成果物はすべて `tmp/issues/<issue番号>/` 配下
- **成果物の 2 種生成(md/.html)**: research / plan / report / review-plan / review は md(正・スキル間の伝達用)と html(人間レビュー用ビュー)の 2 種。スキルは md を読み、無ければ html にフォールバックする。checklist.html は `/test` が結果を書き込む状態ファイルのため html 単一
- **capture-before の自動スキップ**: UI 変更を伴わない issue(checklist.html に「UI 撮影台本」が無い等)では、スキル側が撮影せずスキップを報告する。dev はこの報告を受けたらスキップ扱いとして dev-state.json に記録し、次へ進む

### 実行形態表(tier × ステップ)

値は `agent:<model>/<effort>`(Agent ツールで別コンテキストとして実行。`subagent_type` に **`dev-<model>-<effort>`** を指定し、**`model` 引数は渡さない**)/ `skip`。model はエージェント定義の frontmatter でフル ID に固定してある(`opus` = `claude-opus-5-5[1m]`、`fable` = `claude-fable-5-1`)。Agent ツールの `model` 引数はエイリアスしか受け付けず、`opus` が環境によって **Opus 5 に解決される**ため使わない。**ステップはすべて agent で動かし、inline(セッションモデル)で動くのは dev 本体だけ**。セッションの model / effort はステップの実行には影響しないが、**dev 本体はセッションモデルで動く**ので、セッションは Opus 5.5 以上を推奨する(※4)。

| ステップ | S | M | L | XL | fixed:\<model\>/\<effort\> |
|---|---|---|---|---|---|
| triage-initial | agent:opus/medium(tier 引数指定時は skip) | ← | ← | ← | skip |
| research | skip | agent:opus/high | agent:fable/high | agent:fable/xhigh | agent:\<model\>/\<effort\> |
| └ ファンアウト Agent(research 内) | — | opus/low | opus/medium | opus/medium | \<model\>/\<effort\> |
| triage-confirm | skip | agent:opus/medium | agent:opus/medium | agent:opus/medium | skip |
| plan | agent:opus/medium(lite) | agent:fable/high | agent:fable/xhigh | agent:fable/max | agent:\<model\>/\<effort\> |
| triage-promote | skip | agent:opus/medium | agent:opus/medium | agent:opus/medium | skip |
| review-plan | skip | agent:opus/high ※1 | agent:opus/xhigh | agent:fable/xhigh | agent:\<model\>/\<effort\> |
| capture-before | skip | agent:opus/low | agent:opus/low | agent:opus/low | agent:\<model\>/\<effort\> |
| implement | agent:opus/medium | agent:opus/xhigh | agent:opus/xhigh | agent:fable/xhigh ※3 | agent:\<model\>/\<effort\> |
| create-pr-text | agent:opus/low | agent:opus/low | agent:opus/low | agent:opus/medium | agent:\<model\>/\<effort\> |
| test | agent:opus/low ※2 | agent:opus/low | agent:opus/medium | agent:opus/medium | agent:\<model\>/\<effort\> |
| review(親: 収集・統合) | agent:opus/low | agent:opus/low | agent:opus/low | agent:opus/low | agent:\<model\>/\<effort\> |
| └ Claude レビュアー Agent(review 内) | opus/medium(正確性・副作用のみ) | opus/high | fable/xhigh | fable/xhigh | \<model\>/\<effort\> |
| quiz | skip | agent:opus/low | agent:opus/medium | agent:opus/medium | agent:\<model\>/\<effort\> |
| notify-discord | agent:opus/low | agent:opus/low | agent:opus/low | agent:opus/low | agent:\<model\>/\<effort\> |
| dev 本体(状態管理・DoD ゲート・config 学習・質問リレー) | inline(セッションモデル。**Opus 5.5 以上を推奨** ※4) | ← | ← | ← | inline |

- triage-initial は tier が未確定の時点で実行するため、tier 引数が無い限り常に agent:opus/medium
- ※1 M の review-plan は、plan.md の「副作用 identifier」セクションが空 **かつ** `.agents/skills-config/review-plan/config.json` の `attentions` に plan の変更対象へ該当する項目が無い場合、dev が自動スキップしてよい(dev-state.json に理由を記録)
- ※2 S の test は checklist の内容に従う(UI 変更が無ければ unit テスト項目だけになり、ブラウザ操作は発生しない)
- ※3 **XL だけ implement を Fable に残す**。XL の定義が「実装方式の候補間でアーキテクチャが変わる / AC が未確定」であり、**plan が具体的になりえない**(実装時にしか決まらない判断が本質的に残る)ため。M / L は plan が「探索の代替」(正確なパス・シグネチャ・テストケース。`/plan` の「記述の原則」)まで書けている前提で Opus に落とす。**effort は tier に関わらず常に xhigh**: 低 effort はツール呼び出しを統合してターン数を減らすが、implement で減るのは**検証のターン**(テスト実行・変更後の再読・確認)であり、安くなった分だけ確認を省いた実装になるため。implement は Opus で動くので effort は Fable 枠に影響せず、下げる動機もない
- **M / L で plan が曖昧だった場合の守りは予測ではなく feedback で行う**: implement が二回目の設計をして失敗したら、test 失敗ループの内側(implement 単独リトライ。**Fable 枠 0**)が拾い、実装では直せないと判断したら `status: needs-replan` で plan 巻き戻しに出る(後述)。内側リトライが安いので、plan 具体度を事前に採点して model を振り分ける機構は置かない(指標を増やすと較正対象が増え、判定を外したときの切り分けも難しくなる)
- ※4 **dev 本体はセッションモデルで動く唯一の部分**。13 ステップの起動・要約の受領・state 更新・HTML オープン・DoD 判定・質問リレーで **80〜100 ターン**を回し、毎ターン文脈全体を再送する(SKILL.md だけで 12〜15k、終盤 30k 前後)。セッションが Fable だと **どのステップより多く Fable 枠を消費しうる**(prompt cache が枠にどう数えられるか不明なため、幅は 50k〜2M)。dev 本体の判断(DoD 証跡の照合・attentions 追記要否・チェックポイント報告)は小さく Opus で足りるので、**セッションは Opus 5.5 以上を推奨**(`/model` の選択肢から明示的に選ぶ。`opus` エイリアスは Opus 5 を指しうるので使わない)。表の Fable 配置はセッションモデルに依存せず、切り替えても各ステップの model は変わらない
- 「└」の行はサブスキル内部で起動する Agent。research / review が tier 引数から model / effort を決める(subagent_type は同じ `dev-<model>-<effort>`)
- `fixed:<model>/<effort>` は `dev-<model>-<effort>` で起動する。`<model>` が `opus` / `fable` 以外(定義が無い)か effort が省略された場合は、**Opus 5 に落ちる可能性があるエイリアス起動はせず**、ユーザーに「定義が無い」と報告して停止する(`auto` でも)
- normal モードで質問が発生しうるステップ(research / plan / implement / test)は「質問リレー」で扱う(後述)。subagent 化のために auto に落とすことはしない
- 線引きの原則: **判断が後段にカスケードするステップ(research 本体・plan・L 以上のレビュアー)だけ Fable に残し、作業・診断寄りのステップは Opus に落とす**。Sonnet / Haiku は精度リスクを取ってまで使わず、安くしたければ Opus の effort を下げる。**Opus は 5.5 以上のみ**(Opus 5 以前は性能面で使わない。エージェント定義のフル ID 固定がその担保)
- **implement を Fable から外す根拠**: implement は全ステップ中最大の消費源だが、plan が「探索の代替」になる具体度(正確なパス・シグネチャ・テストケース)まで書けていれば implement に残る判断は少なく、Opus で足りる。plan が具体的になりえない XL だけ Fable に残す(※3)
- **effort を下げて節約してよいステップ**: 長い文書を一度に書く quiz / create-pr-text / research の執筆部分。**implement と plan では effort を下げない**(前者は減るターンが検証のターンであり、後者は判断の質がそのまま後段にカスケードする)

### エージェント定義の準備(model と effort を固定する)

Agent ツールの `model` 引数はエイリアス(`opus` / `fable` 等)しか受け付けず、`opus` は環境によって Opus 5 に解決される。effort も引数では渡せない。どちらも subagent 定義(`~/.claude/agents/*.md`)の frontmatter でだけ固定できるため、本スキルの `assets/agents/` にある **10 ファイル** `dev-{opus,fable}-{low,medium,high,xhigh,max}.md`(`model` をフル ID で固定 + `effort` 固定)を使う。セットアップ時に次を行う:

1. `~/.claude/agents/dev-opus-*.md` / `dev-fable-*.md` の 10 ファイルが存在し、`assets/agents/` と内容が一致するか `diff -q` で確認する。無い・違うものは `assets/agents/` からコピーする(`mkdir -p ~/.claude/agents`)。旧 `dev-effort-*.md` が残っていれば削除する(`model: inherit` のため、エイリアス経由で Opus 5 に落ちうる)。追加・更新は数秒で自動反映される(再起動不要)
2. ただし `~/.claude/agents/` を今回新規作成した場合(そのスコープで初のエージェント定義)は Claude Code の再起動まで定義が読まれない。その旨をユーザーに伝え、**再起動後の再実行を案内して停止する**
3. `dev-<model>-<effort>` を Agent ツールが受け付けない場合も同様に**停止して報告する**。`general-purpose` + `model` エイリアスへの fallback は行わない(Opus 5 に落ちる経路を残さないため)。dev-state.json に `agents_ready: false` と理由を記録する

## 開始時セットアップ

以下を **1 回の AskUserQuestion にまとめて** 質問する(mode が引数で指定済みならその質問は省く)。このセットアップ質問は mode の「質問しない」制約の適用対象外。

1. **mode**: `auto` / `normal`(推奨: `normal`)
2. **チェックポイント**(multiSelect): triage 以外のステップ 2〜12 のうち「完了後に停止して内容を確認したいステップ」を 0 個以上(デフォルト: なし)

3. **セッションモデル**(セッションが Opus 5.5 以上でないときだけ表示): `このまま続行` / `中断して /model で切り替え後に再実行`(推奨: 中断して切り替え)。理由は実行形態表 ※4

スキップするステップは tier から決まるため、個別に質問しない。特定ステップを飛ばしたい場合は tier 引数で調整する(例: research を飛ばすなら `S`)。

### セッションモデルの確認

セットアップ質問を出す前に、自身が動いているモデルを確認する(システムプロンプトのモデル名で判定)。

- **Opus 5.5 以上**: 何もしない(質問 3 は出さない)
- **Fable**: 質問 3 を含める。理由は Fable 枠の消費(※4)
- **Opus 5 以前 / Sonnet / Haiku**: 質問 3 を含める。理由は dev 本体の判断精度(DoD 判定・config 学習)
- 「中断」が選ばれたら dev-state.json を書かずに終了し、`/model` で Opus 5.5 以上を選んで `/dev <同じ引数>` を再実行するよう案内する。「続行」なら `session_model` を dev-state.json に記録して進める(**auto でも質問 3 は出す**。セットアップ質問は mode の適用対象外)
- `fixed:fable/...` / `full` 指定時も同じ(各ステップが Fable で動くことと、dev 本体が Fable で動くことは別の消費)

セットアップ質問の直後に「エージェント定義の準備」(前述)を行い、`agents_ready` を dev-state.json に記録する。

## tier の確定と反映

1. tier 引数が指定されていればそれを採用し、`tier_source: "user"` とする。triage は呼ばない
2. 指定が無ければ、セットアップ直後に `triage-initial` を実行して仮 tier を得る(S の見極めが目的。迷えば M になる)
3. research 完了後に `triage-confirm` で確定する。**以降のステップの model / effort・スキップはこの結果で決める**
4. plan 完了後に `triage-promote` を実行し、昇格があれば以降に反映する(降格はしない)
5. tier が確定・変化するたびに dev-state.json の `tier` / `tier_source` を更新し、`normal` モードでは確定時に 1 回だけ「tier と各ステップの model / effort(実行形態表の該当列)」を提示して続行可否を確認する(`auto` は提示のみで続行)。triage が `source: default`(Jev も fallback も失敗)を返した場合は mode に関わらず確認する

## 状態の永続化(dev-state.json)

セットアップ完了時に `tmp/issues/<issue番号>/dev-state.json` を書き出し、ステップの開始・完了・ループ突入・tier 変更のたびに更新する。

```json
{
  "issue": 123,
  "issue_url": "https://github.com/<owner>/<repo>/issues/123",
  "mode": "normal",
  "tier": "M",
  "tier_source": "jev",
  "fixed": null,
  "checkpoints": ["plan", "review"],
  "skips": ["quiz"],
  "agents_ready": true,
  "session_model": "claude-opus-5-5[1m]",
  "models": { "triage-initial": "opus/medium", "research": "opus/high", "plan": "fable/high" },
  "timings": { "research": { "started": "2026-10-08T10:00:00+09:00", "finished": "2026-10-08T10:12:30+09:00" } },
  "agents": { "research": "<agentId>" },
  "loops": { "review_plan": 0, "test_inner": 0, "test_outer": 0, "review": 0 },
  "test_failures": [["[AC2] 不正なメールでエラー"], ["[AC2] 不正なメールでエラー"]],
  "steps": { "triage-initial": "completed", "research": "in_progress" }
}
```

- `issue_url` はセットアップ時に `gh issue view <issue> --json url -q .url` で取得して記録する(ビューアがリンクにする。取得できなければ省略)
- `skips` は tier から導出した結果(自動スキップ含む)の記録。人が選ぶ項目ではない
- `fixed` は `fixed:` 指定時のみ `{ "model": "opus", "effort": "high" }`
- `models` は各ステップを実際に起動した `<model>/<effort>` の記録(ループで再実行しても同じ model なら上書きでよい)。`timings` はステップの開始・完了時刻(ISO 8601)。どちらもビューアの dashboard が表示する。`agents` は質問リレーの再開に使う agentId(ステップ完了時に消してよい)
- `agents_ready` は `dev-<model>-<effort>` 定義で起動できたか(false なら停止している。fallback は無い)
- `session_model` は dev 本体が動いているモデル。Fable のまま続行した run を後から集計で見分けるために記録する
- `loops.test_inner` は外側に出るたび 0 にリセットする。`test_failures` は内側の各ラウンドで失敗した checklist 項目名の配列(早期エスカレーション判定に使う。外側に出たらクリアする)
- `/dev` 開始時に同 issue の dev-state.json が既に存在する場合は内容を読み、未完了の最初のステップからの再開をユーザーに提案する(auto では自動で再開)。tier は記録済みの値を使う

## 成果物ビューア(1 タブで全成果物を見る)

ステップごとに html を別タブで開くと、ループの再生成も含めてタブが増え続ける。代わりに本スキルの `assets/viewer.html`(左に成果物一覧、右に iframe)を **issue ごとに 1 タブだけ** 開き、以降はそのタブを使い回す。

- **URL**: `file://<本スキルの assets/viewer.html の絶対パス>?dir=file://<成果物ディレクトリの絶対パス>/#<page>`(`dir` は末尾 `/` 付き。viewer.html は成果物ディレクトリにコピーしない)
- **開くタイミング**: dev-state.json を書き出した直後(セットアップ完了時)に `/open <URL>#dashboard` で 1 回開く。以降は各ステップ完了後に `#<page>` 付きで `/open` を呼ぶだけでよい。`/open` は同 URL のタブがあればリロード、ハッシュ違いならページ内遷移にするので(open スキルの「開き方」)、タブは増えない
- **ビューアの挙動**: 先頭の `dashboard` は dev-state.json を描画したページ(進捗バー・ステップ表・ループ・DoD)。3 秒ごとに `dev-state.json` と各 html を fetch し、未生成はグレー、更新ありは黄、進行中ステップ(`steps` が completed / skipped 以外)は紫で表示する。表示中ページが更新されるとスクロール位置を保ってリロードする。open スキルの config に `--allow-file-access-from-files` が必要(open スキルが自動で追記する)
- `/open` が `"browser": "default"` の場合も同じ URL を開くが、既定ブラウザでは `file://` の fetch が効かないため一覧がグレーのままになる。その場合は従来どおり個別 html を `/open` で開く(dev-state.json に `viewer: false` を記録)

| ステップ | page | 備考 |
|---|---|---|
| (セットアップ完了時) | `dashboard` | dev-state.json から進捗・各ステップの model / effort・所要時間・ループ回数・DoD を表示(自動更新) |
| research | `research` | |
| plan | `plan` | checklist.html も同時生成されるが plan を表示 |
| review-plan | `review-plan` | |
| implement | `report` | |
| test | `checklist` | compare.html があれば `compare` |
| review | `review` | review-claude / review-codex / context は一覧に出さない(中間成果物) |
| quiz | `quiz` | |

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
3. **実行**: 実行形態表に従って Agent ツールで起動する(`subagent_type: dev-<model>-<effort>`。後述「agent ステップの依頼形式」)。normal で `status: needs-input` が返ったら「質問リレー」で回答を戻して再開する
4. **ビューアの切り替え**: 個別の `.html` は開かない。ステップ完了後に Skill ツールで `/open <ビューア URL>#<page>` を呼び、「成果物ビューア」の該当ページに切り替える(page はステップ → page 表のとおり。ループでの再生成・更新時も同様。ビューアは変更を自動検知して表示中ページをリロードするので、切り替え以外の操作は不要)
5. **チェックポイント判定**: 指定されていれば停止する(「チェックポイント停止の挙動」参照)

### mode の挙動

| mode | 挙動 |
| --- | --- |
| `auto` | パイプライン中はユーザーに質問しない。plan の方針選択・曖昧な要件・config 追記もすべて推奨案で自動決定し、**置いた仮定は各成果物に明記させる** |
| `normal` | plan の方針選択・config 追記の承認・tier 確定時の確認のみ質問する。それ以外は中断せず進める |

- mode はサブスキルの呼び出し引数として明示的に渡す(例: `/plan 123 normal`)。normal でも auto に落とさない
- subagent には AskUserQuestion が無い(対話セッションでは subagent は常に background で動く)。normal での質問は「質問リレー」で dev が代行する。並列グループ(A / B)のうち質問が発生しうるのは test だけで、それもリレーで扱える
- チェックポイント停止・ループ上限到達時の報告は mode に関わらず必ず行う

### agent ステップの依頼形式

Agent ツール(`subagent_type: dev-<model>-<effort>`。実行形態表の値。`model` 引数は渡さない)で起動し、プロンプトに以下を含める:

- Skill ツールで対象スキルを実行すること(例: `Skill ツールで review-plan を args「123」で実行してください`)。呼び出し引数はステップ定義表のとおり(mode を取るスキルには dev の mode をそのまま渡す)
- リポジトリルートと成果物ディレクトリ(`tmp/issues/<issue番号>/`)の**絶対パス**
- mode が `auto` のとき: 「ユーザーへの質問はできない。判断に迷う場合は保守的に倒し、その旨を成果物に明記する」という制約
- mode が `normal` のとき: 「AskUserQuestion は使えない。質問が必要になったら `tmp/issues/<issue番号>/questions.json` に書き、最終メッセージを `status: needs-input` として一旦終了せよ。回答は再開時のメッセージで渡す」という質問リレーの指示(フォーマットは後述)
- 「検索は Grep ツールまたは `git grep` / `rg` を使い、Bash の `grep -r` / `find <dir>` は使わない(gitignore された `.secret.local` 等の deny ルール対象ファイルを走査して承認待ちになる)」という制約
- 最終メッセージの 1 行目は `status: done` または `status: needs-input`。続けて返すサマリの形式:
  - triage: tier / source / 決め手(3 行)
  - research: AC 数、未確認の仮定の件数、難易度シグナルの要約(3 行)
  - plan: 選択した実装方法、タスク数、副作用 identifier 数、tier 昇格推奨の有無(lite 時)
  - implement: 完了したタスク数、Deviations の件数、`fix` 時は直した内容(または `status: needs-replan` と plan の何を直すか)
  - review-plan: 判定(OK / 差し戻し)、must / should / OK の件数、must の要旨(1 行ずつ)
  - implement: 変更ファイル数、Deviations の件数と要旨、lint / type check の結果
  - review: must / should / nit の件数、両者一致の件数、ブロッカー概要、総合判断
  - test: 失敗項目の有無と件数、compare.html の有無
  - capture / create-pr-text / quiz / notify-discord: 生成した成果物のパスと要点(capture はスキップ理由があればそれ)

起動時に返る agentId を dev-state.json の `agents` に記録する(質問リレーの再開に使う)。

### 質問リレー(normal モードの subagent からの質問)

1. `status: needs-input` が返ったら `tmp/issues/<issue番号>/questions.json` を読み、その内容を**そのまま** AskUserQuestion でユーザーに提示する(質問文・選択肢・multiSelect を変えない。自由入力も受け付ける)
2. 回答を questions.json の `answers` に書き込み、SendMessage で同じ subagent(`agents` に記録した agentId)に「questions.json に回答を書いた。続きから進めよ」と送って再開する。再開した subagent は文脈を保持したまま続きから進む
3. `status: done` が返るまで 1〜2 を繰り返す(research は 1 テーマずつ質問するので複数回になりうる)
4. 再開できない(subagent が失われた等)場合は、questions.json の回答を含めて同じステップを新規起動する(サブスキルは既存成果物と回答を読んで再開する)

questions.json のフォーマット(AskUserQuestion と同じ構造):

```json
{
  "step": "research",
  "round": 1,
  "questions": [
    { "question": "...", "header": "AC", "multiSelect": false,
      "options": [ { "label": "...", "description": "..." } ] }
  ],
  "answers": null
}
```

`answers` は `{ "<question>": "<回答(自由入力含む)>" }` の形で dev が書く。チェックポイント停止・tier 確定時の確認は dev 自身の質問なのでリレーの対象外。

### 並列グループの実行

- **グループ A(create-pr-text ∥ test)**: 2 つの subagent を**同一メッセージで並列起動**する。両方の完了(test は `status: done`)を確認してから review へ進む
- **グループ B(quiz ∥ notify-discord)**: 同様に同一メッセージで並列起動し、両方の完了を確認してから `/dev` を終了する
- グループ内のステップに**チェックポイントが指定されている場合、そのグループは表の順の直列実行に落とす**
- グループ内の片方がスキップされた場合、残りを単独で通常実行する

### notify-discord への引数

dev が実施内容のサマリを組み立てて `/notify-discord <サマリ>` として渡す。**pitch の要領**(結論・成果を先頭に、続けて要点)で構成する: 何ができたか(1-2 行)→ tier と使ったモデル → テスト・レビュー結果の要点 → 実施ステップ → 主要成果物のパス(詳細な解説は quiz.html の解説パートを案内)。notify-discord 側からユーザーへの質問が発生しない状態で呼び出すこと(`webhook_url` 未設定なら dev が事前に検出し、そのステップだけ inline で実行する)。

## ループ(4 種)と上限

test 失敗ループは **内側(implement 単独リトライ)と外側(plan 巻き戻し)の二段** に分かれる。内側は implement と test だけを回すので **plan(Fable)を消費しない**。外側に出ると plan の再実行が発生するため、**内側を使い切ってから外側に出る**。

| ループ | 発動条件 | 戻り先 | 上限(S) | 上限(M 以上・fixed) |
|---|---|---|---|---|
| review-plan 差し戻し | 修正必須(must)が 1 件以上 | plan(修正)→ review-plan 再実行 | —(S は review-plan なし) | 3 回 |
| **test 失敗(内側)** | チェックリストに失敗項目 | **implement(失敗項目の修正)→ test 再実行**。plan には戻さない | test 実行 1 回 | **test 実行 3 回** |
| **test 失敗(外側)** | 内側が上限到達、または**早期エスカレーション条件**に該当 | plan(更新)→ review-plan → implement → …(表の順に再実行。**capture-before と triage は除く**) | 0 回(S は即 M 昇格) | **1 回** |
| review 差し戻し | must 指摘が 1 件以上 | implement(指摘の修正)→ review 再実行 | review 実行 2 回 | review 実行 3 回 |

- **早期エスカレーション条件**: 内側で **同一の checklist 項目が 2 回連続して失敗**したら、内側上限を待たずに外側へ出る。同じ箇所で 2 回転ぶのは実装の揺らぎではなく計画の欠陥のサインで、3 回目を回しても同じ箇所で転ぶため(待ち時間の純損失)。失敗項目が毎回違う場合は内側上限まで回す。判定には `checklist.html` の失敗項目を使い、各ラウンドの失敗項目を dev-state.json の `test_failures` に記録する
- 外側に出るたび内側カウントを 0 にリセットする。**最悪ケースの test 実行回数 = 内側 3 × (外側 1 + 1) = 6 回**
- **外側を 1 回に絞る理由**: 内側と外側は目的が違う。内側は**実装の欠陥**を直し、ラウンドごとに失敗項目が変わるなら情報が増えている。外側は**計画の欠陥**を直すもので、1 度書き直してもなお失敗するなら「必要な情報がパイプラインに入っていない」(AC が曖昧 / research が足りない / 暗黙の前提が違う)という証拠であり、同じ入力で同じエージェントがもう一度書き直しても出てこない。**そこが人に渡すべき点**。外側 1 周あたり plan の Fable 110k を払うことも考えると、2 周目の期待値は低い
- 各ループは**独立にカウント**し、dev-state.json の `loops` に記録する
- **S で上限に達した場合は tier 判定の誤りとみなし、tier を M に昇格して(`tier_source: "loop-promote"`)残りのステップを M として続行する**(research は飛ばしたまま。review-plan と quiz は以降有効になる)。M 以上で上限に達しても解消しない場合はループを終了し、状況をユーザーに報告して判断を仰ぐ(**auto でもここは停止する**)
- **内側リトライでの implement 再実行は `/implement <issue> <mode> fix` で起動し、失敗した checklist 項目と `/test` の失敗内容をプロンプトに渡す**(何を直すべきか分かる状態で起動する)。計画自体の変更はさせない
- **implement が `status: needs-replan` を返したら、内側カウントに関わらず即座に外側へエスカレーションする**(「計画を直さないと実装では直せない」という implement 側からの申告)。返ってきた「plan の何を直す必要があるか」を `/plan` の再実行プロンプトに渡す
- review 差し戻しループの implement も同様に `fix` で起動し、must 指摘をプロンプトに渡す
- 再計画・修正時は `tmp/issues/<issue番号>/` の既存成果物を新規作成し直すのではなく、失敗・指摘内容を反映して**更新**する
- **review ループで実装が変わった場合は pr.md も更新する**(create-pr-text を agent で再実行)
- ループ再突入時の確認頻度は mode に従う(auto: 確認なし、normal: 再計画時の方針選択のみ)

## 完了の定義(DoD)ゲート

review ループを抜けたら、グループ B に進む前に plan.md の「完了の定義(Definition of Done)」を読み、各項目の充足を検証する。

- 各項目を**証跡に基づいて**判定する(例: checklist.html の全項目が checked / review.md の must が 0 / lint・type check が pass / 必要なドキュメント更新済み)
- 判定結果を dev-state.json に記録する
- **未充足項目がある場合**: 対応するループに戻る。checklist 由来の未充足は **まず test の内側ループ**(implement 単独リトライ)に戻し、内側が上限到達済みなら外側へ。review 由来は review ループへ。該当ループが上限到達済みならユーザーに報告して判断を仰ぐ
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

- mode に応じた質問頻度を守る。セットアップ質問(セッションモデルの確認を含む)・tier 確定時の確認(normal)・チェックポイント停止・ループ上限到達時の報告・DoD 未充足かつループ上限到達時の報告は mode の適用対象外(必ず行う)
- 成果物 html を増やす場合は `assets/viewer.html` の `PAGES` と「成果物ビューア」の表に 1 行ずつ足す
- ステップの増減・並列グループ・実行形態の変更はステップ定義表と実行形態表の修正だけで完結させる。**サブスキルの SKILL.md に model / effort を書かない**(frontmatter の model 上書きは静的で、そのターンの残り全体に残るため fixed と両立しない)。model と effort の器は `assets/agents/dev-{opus,fable}-*.md` の 10 定義だけで、値の割り当ては実行形態表が持つ。**Opus 5 に解決されうるエイリアス起動(`model: opus`)はどこにも書かない**
- サブスキル間の成果物規約(必須セクション・フォーマット)は各サブスキルの SKILL.md が定義する。dev は **成果物パスの受け渡し・実行順序・実行形態(model)・HTML 成果物のオープン・ループ・状態管理** にのみ責務を持つ
- subagent の結果が返らない・失敗した場合は 1 回だけ再実行し、それでも失敗したら inline 実行(Skill ツールで本会話内)に切り替える(セッションの model / effort で動くことになるが、止まるよりよい。dev-state.json の `models` に `inline` と記録する)

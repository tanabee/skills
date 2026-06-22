---
name: dev
description: GitHub issue から計画・実装・チェックリスト・PR テキストまで一気通貫で行う。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Task, Skill, AskUserQuestion
disable-model-invocation: true
---

GitHub issue ( $ARGUMENTS ) に対して、計画から PR テキスト作成まで一気通貫で実行する。

## 引数

`$ARGUMENTS` は `<issue> [mode]` の形式で受け取る。

- `<issue>`: issue 番号（`123`、`#123`）または URL。必須。空の場合はユーザーに issue 番号を質問する。URL が渡された場合は issue 番号を抽出し、以降のステップには正規化済みの issue 番号（例: `123`）を渡す。
- `[mode]`: 慎重度合い。`auto` / `normal` / `careful` のいずれか。省略可。

## モード

| mode | 挙動 |
| --- | --- |
| `auto` | ユーザーに一切質問せず、plan の方針選択も推奨案で自動決定して最後まで進める |
| `normal` | plan の方針選択のみユーザーに質問する。それ以外は中断せず最後まで進める |
| `careful` | 各ステップの開始前と、重要な判断ポイントでユーザーに確認を取る |

`mode` が省略された場合は、最初の手順として AskUserQuestion で mode を選択してもらう（デフォルト推奨は `normal`）。

## レビューポイント（チェックポイント）の選択

**mode に関わらず**、`/dev` の開始時に `AskUserQuestion` で「どのステップ完了後にユーザーが内容を確認・レビューするためにいったん停止するか」を選択してもらう。これは `auto` / `normal` で勝手に最後まで進んでしまうのを防ぐためのユーザー制御点。

### 質問内容

`multiSelect: true` で以下の選択肢を提示し、停止してほしいポイントを 0 個以上選んでもらう（デフォルトは全選択なし = 中断なし）:

- `research` 完了後（plan に進む前）
- `plan` 完了後（review-plan に進む前）
- `review-plan` 完了後（implement に進む前）
- `implement` 完了後（create-checklist に進む前）
- `create-checklist` 完了後（create-pr-text に進む前）
- `create-pr-text` 完了後（test に進む前）
- `test` 完了後（review に進む前）
- `review` 完了後（notify-discord に進む前）

選択結果は内部状態として保持し、各ステップの完了後に該当する場合は停止する。

### 停止時の挙動

選択されたチェックポイントに到達したら、`/dev` の進行を**一時停止**し、ユーザーに以下を提示する:

- 直前ステップの成果物のパス（例: `tmp/issues/<issue番号>/plan.html`）
- 次に実行されるステップ

その上で `AskUserQuestion` で以下の選択肢を提示する:

- **続行**: 次のステップに進む
- **中断**: ここで `/dev` を終了する（残タスクは `cancelled` にする）
- **前のステップを再実行**: 直前のステップをやり直す（成果物は更新モードで再生成）

ユーザーが回答するまで次のステップに進まない。

### mode との関係

- `auto` / `normal` / `careful` のいずれでも、選択されたチェックポイントでは必ず停止する
- `careful` モードはチェックポイント選択とは独立に「各ステップの開始前」での確認も従来どおり行う
- チェックポイントが 0 個 = 従来どおり mode の挙動だけで進行

## スキップするステップの選択

レビューポイント選択に続けて、**`/dev` の開始時に `AskUserQuestion` で「スキップするステップ」を選択してもらう**。「PR を作らないので create-pr-text は不要」「ローカル動作確認だけで Discord 通知は要らない」のように、毎回全 9 ステップを回す必要がない場合の制御点。

### 質問内容

`multiSelect: true` で以下の選択肢を提示し、スキップしたいステップを 0 個以上選んでもらう（デフォルトは全選択なし = すべて実行）:

- `research` をスキップ
- `plan` をスキップ
- `review-plan` をスキップ
- `implement` をスキップ
- `create-checklist` をスキップ
- `create-pr-text` をスキップ
- `test` をスキップ
- `review` をスキップ
- `notify-discord` をスキップ

選択結果は内部状態として保持する。

### スキップ時の挙動

- 該当ステップに到達した時点で Skill 呼び出しを行わず、対応する Task を `cancelled` に更新して次のステップへ進む
- スキップされたステップが**他ステップの前提成果物を生成するもの**（例: `plan` → `plan.html` を `implement` が参照）の場合、後続ステップは既存の成果物（前回実行時のもの）を利用する。存在しなければユーザーに警告し、続行可否を確認する
- 同様に**サブループの起点**（`/test` の失敗ループ、`/review-plan` のサブループ）がスキップされた場合は当該ループも発生しない
- スキップしたステップに対応するレビューポイントが選択されていた場合、そのチェックポイントは無効化する（実行されないステップで停止する意味がないため）

### 整合性チェック

選択結果に明らかな矛盾がある場合は警告してユーザーに再選択を促す:

- `plan` をスキップしたが `implement` を実行する場合 → `plan.html` の事前存在を確認し、無ければ警告
- `create-checklist` をスキップしたが `test` を実行する場合 → `checklist.html` の事前存在を確認し、無ければ `/test` 内の fallback（チェックリストをその場で作成）に委ねる

### mode との関係

- `auto` / `normal` / `careful` のいずれでも、選択されたスキップ設定は必ず適用される
- スキップが 0 個 = 従来どおり全 9 ステップを実行

## タスク管理（Task ツール）

`/dev` の進行状況は Claude Code の **Task ツール（TaskCreate / TaskUpdate / TaskList）** で管理する。ユーザーに進捗が可視化されると同時に、再開時の状態把握にも使う。

### 初期化

mode 選択（必要なら）、**レビューポイント選択**、**スキップステップ選択**が完了したら、`TaskCreate` で以下 9 タスクを一括登録する（**スキップ対象は最初から `cancelled` で登録**し、残りは `pending`）:

1. `research` — issue 調査
2. `plan` — 実装計画作成
3. `review-plan` — 計画レビュー
4. `implement` — 実装
5. `create-checklist` — 動作確認チェックリスト作成
6. `create-pr-text` — PR テキスト作成
7. `test` — ブラウザ動作確認
8. `review` — コードレビュー
9. `notify-discord` — Discord 通知

### 進行管理ルール

- 各ステップに入る直前に該当タスクを `TaskUpdate` で `in_progress` に変更
- ステップが正常完了したら即座に `completed` に変更（**バッチ更新しない**）
- 同時に `in_progress` にできるのは **1 タスクのみ**
- サブループ（`/review-plan` で修正必須、`/test` で失敗）に入った場合は、既存タスクを `in_progress` のまま保ち、必要に応じて TaskCreate でループ内サブタスク（例: `replan-round-2`）を追加してよい
- ループ完了後にサブタスクを `completed` に、本流タスクも `completed` に進める
- 上限到達で失敗終了した場合は該当タスクを `cancelled` にし、後続タスクも `cancelled` にする

## 実行手順

以下の順に各スキルを Skill ツールで呼び出す（`<issue番号>` は上記で正規化したもの）。各ステップ開始時に対応する Task を `in_progress` に、完了時に `completed` に更新する。

1. `/research <issue番号>` — issue に関連するコードベースや背景情報を調査する
2. `/plan <issue番号>` — 実装計画を作成し、方針を決定する（`normal` / `careful` ではユーザーに選択してもらう）
3. `/review-plan <issue番号>` — plan の影響範囲を独立視点で検証する。**修正必須が 1 件以上**ある場合は step 2 (`/plan`) に戻って計画を修正してから再度 `/review-plan` を実行する（このサブループは plan 修正で OK が出るまで繰り返す。上限 3 回）
4. `/implement <issue番号>` — 計画に基づいてコードを実装する
5. `/create-checklist <issue番号>` — 動作確認チェックリストを作成する
6. `/create-pr-text <issue番号>` — PR のタイトルと説明文を作成する
7. `/test <issue番号>` — チェックリストに沿ってブラウザで動作確認テストを実行する
8. `/review <issue番号>` — コードレビューを行う
9. `/notify-discord` — Discord に実施内容を簡潔にリッチテキスト形式で送信する

## テスト失敗時の再計画ループ

step 7 (`/test`) でチェックリストの項目に失敗が発生した場合、step 2 (`/plan`) に戻ってやり直す。

- 再計画時は `tmp/issues/<issue番号>/` 配下の既存成果物（`plan.html` / `checklist.html` / `pr.md` など）を新規作成し直すのではなく、失敗内容を反映して**更新**する。各サブスキルは既存ファイルがあれば追記・修正の方針で動作する想定
- 再計画後は step 3 (`/review-plan`) を必ず再度実行する
- `/implement` 以降も、既存の実装・チェックリスト・PR テキストを失敗内容に応じて修正する
- ループ上限は **3 回**（初回実行 + 再計画 2 回 = 最大 3 回の `/test` 実行）。上限に達してもテストが通らない場合はループを終了し、失敗内容をユーザーに報告して判断を仰ぐ
- ループ再突入時の質問頻度は mode に従う。`auto` は確認なしで即ループ、`normal` も原則ループは自動で回すが再計画時の方針選択のみ質問、`careful` は各ループの開始前にユーザーに継続可否を確認

## config への学習機構（手戻りを防御に変換する）

step 7 (`/test`) の失敗、または step 8 (`/review`) の指摘で、**plan が見落としていた間接依存・暗黙の必須セット・カスケード**が判明した場合、それを今後の `/plan` と `/review-plan` で防げるよう、両スキルの `config.json` の `attentions` 配列に追記する。

### 追記の判断基準

以下のいずれかに該当する場合、追記候補とする:

- 「コードに直接現れない依存」だった（trigger / subscriber / 設定 / 暗黙の必須セット等）
- プロジェクト固有のフレームワーク慣習が原因だった（特定のディレクトリにある自動登録など）
- 同種の手戻りが今後別 issue でも起きうる汎用的な内容である

逆に、以下は追記しない:
- その issue 限りの個別事情
- コード grep で素直に辿れる直接依存
- 既に同等の内容が `attentions` に存在する

### 追記内容のフォーマット

`attentions` には自然言語 1 行（または短い段落）で記述する。例:

```
"Firestore `orders/{orderId}` への書き込みは functions/src/triggers/onOrderWrite.ts を発火し、Discord 通知文面の更新も必要"
```

### 追記先

`skills/plan/config.json` と `skills/review-plan/config.json` の **両方** に同じ内容を追記する（完全重複運用）。

### mode ごとの挙動

- `auto`: ユーザー確認なしで両 config に自動追記
- `normal`: 追記候補の内容と追記先をユーザーに提示し、承認されれば追記
- `careful`: 追記候補ごとに追記要否と文言をユーザーに確認

## 注意事項

- mode に応じた質問頻度を守る。`auto` では一切質問しない、`normal` では plan の方針選択と config 追記の承認のみ、`careful` では各ステップ前に確認する
- `auto` / `normal` の場合、mode で定められていないタイミングでは中断せず最後まで進める
- **ただし、開始時に選択されたレビューポイントでは mode に関わらず必ず停止する**（「レビューポイント（チェックポイント）の選択」参照）
- **開始時にスキップ指定されたステップは Skill 呼び出しを行わず Task を `cancelled` にして次へ進む**（「スキップするステップの選択」参照）
- テスト失敗時は上記「テスト失敗時の再計画ループ」に従う
- `/review-plan` で修正必須が出た場合は plan の修正 → `/review-plan` 再実行のサブループを回す（上限 3 回）。これはテスト失敗ループとは独立にカウントする

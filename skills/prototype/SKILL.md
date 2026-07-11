---
name: prototype
description: アイデアの壁打ちから、動くプロトタイプ＋デモ一式（起動確認・スクショ・デモ手順）まで一気通貫で伴走する。
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion, WebFetch
disable-model-invocation: true
---

アイデア（ $ARGUMENTS ）を、壁打ちで磨いた上で動くプロトタイプに仕立てる。research / plan などの重いプロセスは踏まず、スピードと「本実装の種になる品質」の両立を狙う。

## 引数

`$ARGUMENTS` はアイデアの自由記述（例: `レシピ共有アプリ`）。省略時はステップ 1 の壁打ちをゼロから始める。

## config.json

このファイルと同じディレクトリの `config.json` に、ユーザーの定番設定を蓄積する（無ければ初回に作成する）。

- `prototypes_dir`: プロトタイプ置き場のデフォルト（例: `~/dev/prototypes`）
- `preferred_stacks`: 過去に選ばれたスタックの傾向（スタック提案時の推奨度に反映する）
- `stack_skills`: スタック別に有用だった Agent Skill の蓄積（ステップ 4 の定番表に加えて参照する）

## 手順

### 1. 壁打ち（発散 → 収束）

1. **発散**: アイデアに対して、拡張案・類似サービスとの比較・差別化ポイント・想定ユーザーを提示し、AskUserQuestion で 1 テーマずつ対話して膨らませる（一度に大量の質問を並べない）
2. **収束**: 出てきた要素から **コア体験を 1 つ** に絞り込む。プロトタイプで検証したいことを一文で言語化し、ユーザーの合意を得る

### 2. 簡易スペック合意

目的（コア体験）・画面/コマンド一覧・機能リスト・ダミーデータ方針を短い仕様メモにまとめ、ユーザーの OK を得てから着手する。詳細な設計書は書かない。

### 3. スタック提案

コア体験に適した技術スタックを 2〜3 案、推奨度（5 段階）と理由付きで提示し、ユーザーが選択する。Web / CLI / モバイルのいずれも候補にしてよい。`config.json` の `preferred_stacks` があれば推奨度に反映する。

### 4. Agent Skill の導入

選んだスタックに合う Agent Skill を find-skills で探し、有用なものがあれば導入する。

1. まず下表の **スタック別定番スキル** を確認し、該当するものは検索を待たず導入候補に含める（`config.json` の `stack_skills` に蓄積があればそちらも加える）

   | スタック | スキル | 導入コマンド |
   |---|---|---|
   | Web | modern-web-guidance | `npx skills add https://github.com/googlechrome/modern-web-guidance --skill modern-web-guidance` |
   | Web | chrome-devtools-cli | `npx skills add https://github.com/ChromeDevTools/chrome-devtools-mcp --skill chrome-devtools-cli` |
   | Firebase 利用時 | firebase/agent-skills | `npx skills add firebase/agent-skills` で対話選択（firebase-basics + 使うプロダクトのスキルを選ぶ。例: firestore / auth / hosting） |

2. find-skills 未導入なら: `npx skills add https://github.com/vercel-labs/skills --skill find-skills`
3. `npx skills find <スタック名や用途>` で検索する（skills.sh の leaderboard 上位・公式プロバイダを優先）
4. 定番＋検索結果の候補をユーザーに提示し、了承を得て `npx skills add <package>` で導入する。適切なものが無ければ導入せず先に進む

### 5. セットアップ

1. 置き場所を AskUserQuestion で確認する（`config.json` の `prototypes_dir` 配下に新規作成をデフォルト候補にする）
2. プロジェクトを scaffold し、`git init` + 初回 commit を行う

### 6. 実装

簡易スペックの機能リストを実装する。品質方針:

- **本実装の種になる品質**: ディレクトリ構造・命名・責務分離はまともに保つ
- テスト・厳密なエラー処理・エッジケース対応は省略してよい
- ダミーデータで成立させ、外部サービス連携はモックを優先する

### 7. 動作確認とデモ整備

1. 実際に起動して（dev サーバ / CLI 実行 / シミュレータ）コア体験が動くことを確認する
2. スクリーンショット（または録画）を `docs/screenshots/` に保存する
3. `README.md` に起動方法、`docs/` に仕様メモ・デモ手順（見せる順番と操作）を書く
4. 節目として commit する

### 8. フィードバックループ

1. ユーザーに触ってもらい、感想・修正要望を聞く
2. 修正して動作確認し、節目ごとに commit する
3. ユーザーが満足するまで繰り返す。終了時、スタックの選択結果を `config.json` の `preferred_stacks` に、今回有用だった Agent Skill を `stack_skills` に追記する

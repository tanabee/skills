---
name: review
description: Antigravity (agy)・Claude (fable)・Codex (astra) の 3 者による並列コードレビュー。親で差分・コンテキストを 1 回だけ収集し、3 レビュアーを並列実行、結果を統合した review.md / review.html を生成する。
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

**Antigravity (`agy`)**・**Claude (`fable`: `claude-fable-5-1`)**・**Codex (`astra`: `gpt-6-astra`)** の 3 者で並列にコードレビューを行い、結果を統合する。実行環境（agy / Claude Code / Codex CLI 等）を問わず、常にこの 3 レビュアーが独立した視点でレビューを実施する。

**効率化の肝**: 差分取得・PR/Issue 情報収集・ローカル成果物読み込みは**親（本スキル本体）で 1 回だけ**実行し、`diff.patch` と `context.html` としてディスクに書き出す。agy レビュアーと Claude レビュアーはこの 2 ファイルを Read するだけで共通コンテキストを得られる。Codex 側は別レビュアーの独立視点として `/codex-review`（`gpt-6-astra`）を呼び出す。

## 引数

`$ARGUMENTS` は `<対象> [tier]` の形式。`<対象>` は PR 番号/URL または issue 番号/URL（省略可）。`123`、`#123`、PR URL、issue URL のいずれか。`[tier]` は `/dev` から渡される難易度（`S` / `M` / `L` / `XL` / `fixed:<model>[/<effort>]`）で、レビュー観点の範囲や Claude Code 実行時の Agent 設定を決めるために使う（手順 4 参照）。

数値（`123`、`#123`）が渡された場合は、まず `gh pr view <番号>` を試みて PR が存在すれば PR モード、存在しなければ issue 番号として扱いローカルモードに入る。URL の場合は `/pull/` を含めば PR、`/issues/` を含めば issue として判定する。

## レビュー観点

3 レビュアー（agy / Claude / Codex）すべて、以下の観点を網羅的に見る。複数の異なるモデル（Gemini / Claude Fable / GPT-6 Astra）が同じ観点を独立に見ることで、見落としを相互補完する。

| 観点 | 主な確認事項 |
|---|---|
| 正確性 | ロジックのバグ・抜け漏れ、エッジケース（null / 空配列 / 境界値 / 並行処理 / 非同期の競合）、エラーハンドリングの妥当性、条件分岐・ループの網羅性 |
| 設計 | 責務分離、命名、既存パターンとの一貫性、抽象化レベル、モジュール境界・依存の向き |
| 副作用 / 影響範囲 | 変更・削除・リネームしたシンボル（関数・型・定数・ファイルパス・設定キー・環境変数等）の参照元、シグネチャ変更による型エラー、削除した機能の呼び出し元、挙動変更による既存フローへの影響、public API / DB スキーマ / 設定ファイルの破壊的変更 |
| セキュリティ | インジェクション（SQL / コマンド / XSS / SSRF / プロンプトインジェクション等）、認証・認可の不備（権限チェック漏れ、IDOR）、機密情報の漏洩、入力バリデーション、暗号・ハッシュの妥当性 |
| パフォーマンス | N+1 クエリ、計算量、不要な再レンダリング（React の依存配列・memo 化）、不要なアロケーション、ブロッキング操作、キャッシュの有効活用 |
| テスト | テストの網羅性、境界値・異常系のカバレッジ、アサーションの妥当性、過度なモック、テスト粒度、回帰テストの追加 |
| 可読性 | 深いネスト、長すぎる関数、不明瞭な命名、過剰な抽象化、コメントの質、認知負荷の高い構造 |

## タスク管理（Task ツール）

レビュー進行は **タスク管理ツール（TaskCreate / TaskUpdate / TaskList）** で管理する（無い環境では省く）。

### 初期化

スキル開始直後に、以下の 7 タスクを `TaskCreate` で一括登録する（すべて `pending`）:

1. `prepare-output-dir` — 保存先判定と作成
2. `collect-diff` — `diff.patch` の書き出し
3. `collect-context` — `context.html` の書き出し
4. `review-agy` — Antigravity (agy) レビュー
5. `review-claude` — Claude (fable) レビュー
6. `review-codex` — Codex (astra) レビュー（`/codex-review` 呼び出し）
7. `integrate-review` — `review.md` / `review.html` への統合

### 進行管理ルール

- 各ステップに入る直前に該当タスクを `TaskUpdate` で `in_progress` に変更
- ステップが正常完了したら即座に `completed` に変更（**バッチ更新しない**）
- 並列実行ステップ（`review-agy`・`review-claude`・`review-codex`）は **同時に複数を `in_progress` にしてよい**。これは「同時に in_progress にできるのは 1 タスクのみ」の例外として運用する
- いずれかの並列ステップが失敗した場合は該当タスクを `cancelled` にし、残りのレビュアーの結果で `integrate-review` を進めるかユーザーに判断を仰ぐ

## 手順

### 1. 保存先ディレクトリと対象の判定

`$ARGUMENTS` と現在の状態からレビュー対象を判定し、保存先 `<output-dir>` を決定する。

- **PR URL が指定された場合**: PR モード。`gh pr view <番号>` で PR 情報を取得。`<output-dir> = tmp/prs/<PR 番号>`
- **issue URL が指定された場合**: ローカルモード。`<output-dir> = tmp/issues/<issue 番号>`
- **数値（`123`, `#123`）が指定された場合**: まず `gh pr view <番号>` を試み、成功すれば PR モード。失敗（該当 PR なし）した場合は issue 番号として扱いローカルモードに入る。`<output-dir>` はモードに応じて決定
- **`$ARGUMENTS` が空の場合**: `gh pr view` を試み、現在のブランチに PR が存在するか確認する
  - PR が存在する → PR モード。`<output-dir> = tmp/prs/<PR 番号>`
  - PR が存在しない → ローカルモード。ユーザーに関連 issue 番号を質問し（なければスキップ可）、`<output-dir> = tmp/issues/<issue 番号>`（issue 番号が不明な場合は保存先を確認）

`mkdir -p <output-dir>` で作成する。

### 2. 差分をファイルに書き出す（1 回だけ）

親の `Bash` ツールで 1 回だけ実行し、`<output-dir>/diff.patch` に保存する:

- PR モード: `gh pr diff <PR 番号> > <output-dir>/diff.patch`
- ローカルモード: `git diff <base>...HEAD > <output-dir>/diff.patch`(`<base>` は `tmp/config.json` の `base_branch`。無ければ `git remote show origin` の HEAD branch を検出して `tmp/config.json` に保存する)

### 3. コンテキストをファイルに書き出す（1 回だけ）

PR / Issue / ローカル成果物の情報を収集し、`<output-dir>/context.html` に親の `Write` ツールで **HTML** として書き出す。レビュアーはこのファイルを Read してコンテキストを得る。

収集内容:

1. **PR モードの場合**: `gh pr view` の結果から PR タイトル・説明・作成者・関連 issue を取得
2. 関連 issue があれば `gh issue view` で issue の目的・要件を取得
3. **ローカルモードの場合**: `tmp/issues/<issue 番号>/` 配下の既存成果物があれば要点を抽出
   - `plan.md` — 実装計画。意図した設計や変更方針(md が無ければ `plan.html`。以降も同様)
   - `report.md` — 実装レポート。実装者が認識している懸念点や追加変更
   - `implementation-notes.md` — 実装ノート。計画からの逸脱(Deviations)と実装中の判断
   - `checklist.html` — 受け入れテストチェックリスト
   - `pr.md` — PR テキスト

`context.html` のフォーマットは [assets/context-template.html](./assets/context-template.html) を参照。該当しないセクション（例: ローカルモード時の PR 情報、PR モード時のローカル成果物）は省略してよい。

### 4. 3 者レビュー（agy / Claude / Codex）の並列実行

**3 つのレビューを並列に実行する**（独立した視点として動かし、相互に結果を参照させない）。

#### 共通レビュープロンプト（agy / Claude 共通）

agy（4-A）と Claude（4-B）には以下の共通プロンプトを使用する。`<output-file>` は agy なら `review-agy.html`、Claude なら `review-claude.html` に置き換える。**`S` tier では観点を「正確性」「副作用 / 影響範囲」の 2 つに絞る**（`<review-perspectives>` にその 2 行だけ転記し、プロンプトの「全観点」を「この 2 観点」に読み替える）。

```
あなたはコードレビュアーです。以下の入力ファイルを Read してから、全観点を網羅したレビューを実施し、結果を output-path に HTML で Write してください。

## 入力ファイル
- diff-path: <output-dir 絶対パス>/diff.patch
- context-path: <output-dir 絶対パス>/context.html

## 出力先
- output-path: <output-dir 絶対パス>/<output-file>

## レビュー観点（全てを網羅的に見る）

<review-perspectives>

## 手順

1. `diff-path` を Read して差分を取得（`gh` / `git` を自分で叩かない）
2. `context-path` を Read して PR / Issue / 既存成果物の要約を把握
3. diff に現れた変更ファイルごとに、コードベースの該当箇所を Read / Grep で深掘りし、上記全観点でレビュー
4. 結果を `output-path` に HTML で Write して保存

## 出力フォーマット

HTML（`<!DOCTYPE html>` から `</html>` までの完結した HTML）で以下のセクションを `<h2>` 等の見出しで含める:

- **概要**: 変更の骨子（`context.html` を踏まえる）
- **良い点**: 評価できる実装
- **指摘事項**: 重要度別（must / should / nit）に `<h3>` で分け、各指摘に観点タグ（正確性 / 設計 / 副作用 / セキュリティ / パフォーマンス / テスト / 可読性）をバッジで付与
- **まとめ**: 総合判断（マージ可否、ブロッカーの有無）

CSS による重要度の色分け（must=赤 / should=黄 / nit=灰）、観点バッジ、必要に応じて Mermaid 等の図表を活用してよい。

## 制約

- 軽微なスタイル指摘（空白・改行など）は扱わない（リンター責務）
- 指摘には必ず `ファイルパス:行番号` を含める
- 指摘ごとに重要度（must / should / nit）を付与
- 良い点も積極的にコメントする
- コードベースの検索は Grep ツール、または `git grep` / `rg` を使う（gitignore されたファイルを読まない）。Bash の `grep -r` / `find <dir>` は `.secret.local` 等の deny ルール対象ファイルを走査して承認待ちになるため使わない。やむを得ず使う場合は `--exclude='.secret*' --exclude-dir=node_modules` を必ず付ける
```

パスは**絶対パス**で渡す（エージェントや CLI の CWD が親と一致する保証がないため）。`<review-perspectives>` には本 SKILL.md 冒頭の「レビュー観点」セクションの表を**そのまま転記して**展開する（観点表の定義は 1 箇所に保つため、プロンプト内には重複記載しない）。

#### 4-A. Antigravity (agy) レビュー（出力: `<output-dir>/review-agy.html`）

- **実行環境が agy の場合**:
  - `invoke_subagent` ツール（`TypeName: "self"`, `Role: "Antigravity Code Reviewer"`）が利用可能なら subagent を起動して共通プロンプト（`<output-file> = review-agy.html`）を渡す
  - subagent を使わない場合は、4-B・4-C のバックグラウンド実行を先に開始した上で、本スキルを実行している agy 自身が本会話内で同じ観点・同じ出力形式でレビューを実施し `<output-dir>/review-agy.html` に Write する（その際、4-B / 4-C の出力はまだ読まない）
- **実行環境が agy 以外（Claude Code 等）の場合**:
  - Bash ツールで `agy` CLI を非対話実行する。共通プロンプトを `<output-dir>/prompt-agy.txt` に書き出し、以下を実行する（`</dev/null` で stdin 待ちハングを防ぐ）:
    ```bash
    agy -p --mode auto --dangerously-skip-permissions "$(cat <output-dir 絶対パス>/prompt-agy.txt)" </dev/null
    ```

#### 4-B. Claude (fable) レビュー（出力: `<output-dir>/review-claude.html`）

- **実行環境が Claude Code（`subagent_type` を取る Agent ツールがある）の場合**:
  - Agent ツールで `subagent_type: dev-fable-xhigh`（tier 指定がある場合は `S` → `dev-opus-medium`、`M` → `dev-opus-high`、`L` / `XL` / 省略時 → `dev-fable-xhigh`、`fixed:<model>/<effort>` → `dev-<model>-<effort>`。`model` 引数は渡さない）を起動し、共通プロンプト（`<output-file> = review-claude.html`）を実行させる
- **実行環境が Claude Code 以外（agy 等）の場合**:
  - 共通プロンプト（`<output-file> = review-claude.html`）を `<output-dir>/prompt-claude.txt` に Write し、Bash ツールで `claude` CLI を `claude-fable-5-1`（effort `xhigh`）で非対話実行する（`</dev/null` で stdin を閉じる）:
    ```bash
    claude -p --model claude-fable-5-1 --effort xhigh --dangerously-skip-permissions --allowedTools "Read,Write,Grep,Glob,Bash(git grep:*),Bash(rg:*)" "$(cat <output-dir 絶対パス>/prompt-claude.txt)" </dev/null
    ```

#### 4-C. Codex (astra) レビュー（出力: `<output-dir>/review-codex.html`）

- **Skill ツールがある場合（Claude Code 等）**:
  - `Skill` ツールで `codex-review` を呼び出す。`args` には `$ARGUMENTS` の `<対象>`（PR 番号 / URL / 空文字列）を渡す
- **Skill ツールが無い場合（agy 等）**:
  - `skills/codex-review/SKILL.md` の手順に従い、`skills/codex-review/scripts/run-codex-review.sh --base origin/<BASE>`（`--model gpt-6-astra` がデフォルト適用される）を Bash で実行し、その stdout の指摘内容を `skills/codex-review/assets/template.html` に準拠した HTML として `<output-dir>/review-codex.html` に書き出す

#### 並列発行の方法

- **Claude Code 環境**: 同一メッセージ内で `Agent` ツール（4-B）、`Bash` ツール（4-A の `agy -p`）、`Skill` ツール（4-C の `codex-review`）を同時に発行し、3 者の完了を待つ
- **agy 環境**:
  - `4-B`（`claude -p ...`）と `4-C`（`run-codex-review.sh ...`）を `run_command`（または `invoke_subagent`）で並列に起動し、その間に `4-A`（agy 自身のレビュー → `review-agy.html` 作成）を実施する
  - 3 者すべての完了（`review-agy.html`・`review-claude.html`・`review-codex.html` の生成）を確認してからステップ 5 へ進む

### 5. 結果の統合

3 者のレビュー結果（`review-agy.html`・`review-claude.html`・`review-codex.html`）をすべて Read し、統合結果を `<output-dir>/review.md` に書き出す(**md が正**。`/quiz` や `/dev` はこちらを読む)。続けて同じ内容を人間用に `<output-dir>/review.html` としてレンダリングする。

統合時のルール:

- **概要**: PR / Issue の概要と変更の骨子（`context.html` を参照）
- **良い点**: 3 レビュアーから上がった良い点を集約し重複を排除
- **指摘事項**: 重要度別（must / should / nit）にまとめる。各指摘に **レビュアータグ**（`agy` / `claude` / `codex`）を付与。同じ指摘が複数のレビュアーから上がっている場合は統合し、該当するレビュアータグをすべて付ける（**複数レビュアーが独立に指摘 = 確度が高い**として強調表示。特に 3 者一致・2 者一致を明示）。各指摘に観点タグも併記
- **まとめ**: 総合判断（マージ可否、ブロッカーの有無）。agy / Claude (fable) / Codex (astra) の指摘傾向の違い（観点の偏り、見落としの差）にも触れてよい

HTML を採用する理由: 重要度の色分け（must=赤 / should=黄 / nit=灰）・レビュアー別バッジ（`agy` / `claude` / `codex`）・複数一致指摘の強調・`<details>` 折りたたみなど、Markdown では困難な表現を使うため。

統合後の review.md / review.html は以下のセクションを md の見出し(`##`)として含める（html も同構成。テンプレートは置かない）:

- **概要**
- **サマリ**（must / should / nit の件数、3 者一致 / 2 者一致の件数、agy のみ / claude のみ / codex のみの件数）
- **良い点**
- **指摘事項**（must / should / nit を `<h3>` で分け、各指摘にレビュアータグ + 観点タグ）
- **まとめ**

### 6. ユーザーへの提示

`review.html` のサマリ（各重要度の件数、複数一致の件数、ブロッカー概要、総合判断）をユーザーに提示する。詳細は `review-agy.html`・`review-claude.html`・`review-codex.html` を参照するよう案内する（パスを案内するだけで、ブラウザで開くのは統合結果の `review.html` のみ。個別レビューファイルや `context.html` は開かない）。

`<output-dir>/diff.patch` と `<output-dir>/context.html`（および `prompt-*.txt`）は中間成果物として残す（後から再確認や再実行のため）。不要なら手動で削除する。

## 注意事項

- agy・Claude (fable)・Codex (astra) は **独立した視点** として並列で動かす。3 者とも全観点を見るが、相互に結果を参照させない（独立性を保つことで見落としを相互補完する）
- 指摘には必ず該当ファイルと行番号を含める
- 指摘ごとに重要度（must / should / nit）を付与する
- 良い点も積極的にコメントする
- 軽微なスタイルの指摘はリンターに任せ、レビューでは扱わない
- 複数のレビュアーが同じ指摘を独立に挙げた場合は確度が高いとみなし、統合後のレビューで強調する

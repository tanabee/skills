---
name: review
description: Claude Code と Codex CLI による並列コードレビュー。親で差分・コンテキストを 1 回だけ収集し、Claude Code（全観点を一括レビュー）と Codex（`/codex-review` 経由）を並列実行、結果を統合した review.html を生成する。
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

Claude Code と Codex CLI で並列にコードレビューを行い、結果を統合する。

**効率化の肝**: 差分取得・PR/Issue 情報収集・ローカル成果物読み込みは**親（本スキル本体）で 1 回だけ**実行し、`diff.patch` と `context.html` としてディスクに書き出す。Claude Code レビューを担当するエージェントはこの 2 ファイルを Read するだけで共通コンテキストを得られる。Codex 側は別レビュアーの独立視点として `/codex-review` をそのまま呼び出す。

## 引数

`$ARGUMENTS` は PR 番号/URL または issue 番号/URL（省略可）。`123`、`#123`、PR URL、issue URL のいずれか。

数値（`123`、`#123`）が渡された場合は、まず `gh pr view <番号>` を試みて PR が存在すれば PR モード、存在しなければ issue 番号として扱いローカルモードに入る。URL の場合は `/pull/` を含めば PR、`/issues/` を含めば issue として判定する。

## レビュー観点

Claude Code・Codex 双方とも、以下の観点を網羅的に見る。複数のレビュアーが同じ観点を独立に見ることで、見落としを相互補完する。

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

レビュー進行は Claude Code の **Task ツール（TaskCreate / TaskUpdate / TaskList）** で管理する。

### 初期化

スキル開始直後に、以下の 6 タスクを `TaskCreate` で一括登録する（すべて `pending`）:

1. `prepare-output-dir` — 保存先判定と作成
2. `collect-diff` — `diff.patch` の書き出し
3. `collect-context` — `context.html` の書き出し
4. `review-claude` — Claude Code レビュー（Agent 呼び出し）
5. `review-codex` — Codex レビュー（`/codex-review` 呼び出し）
6. `integrate-review` — `review.html` への統合

### 進行管理ルール

- 各ステップに入る直前に該当タスクを `TaskUpdate` で `in_progress` に変更
- ステップが正常完了したら即座に `completed` に変更（**バッチ更新しない**）
- 並列実行ステップ（`review-claude` と `review-codex`）は **同時に両方を `in_progress` にしてよい**。これは「同時に in_progress にできるのは 1 タスクのみ」の例外として運用する
- いずれかの並列ステップが失敗した場合は該当タスクを `cancelled` にし、もう一方の結果のみで `integrate-review` を進めるかユーザーに判断を仰ぐ

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

PR / Issue / ローカル成果物の情報を収集し、`<output-dir>/context.html` に親の `Write` ツールで **HTML** として書き出す。Claude Code レビュアーはこのファイルを Read してコンテキストを得る。

収集内容:

1. **PR モードの場合**: `gh pr view` の結果から PR タイトル・説明・作成者・関連 issue を取得
2. 関連 issue があれば `gh issue view` で issue の目的・要件を取得
3. **ローカルモードの場合**: `tmp/issues/<issue 番号>/` 配下の既存成果物があれば要点を抽出
   - `plan.html` — 実装計画。意図した設計や変更方針
   - `report.html` — 実装レポート。実装者が認識している懸念点や追加変更
   - `implementation-notes.md` — 実装ノート。計画からの逸脱(Deviations)と実装中の判断
   - `checklist.html` — 受け入れテストチェックリスト
   - `pr.md` — PR テキスト（`/create-pr-text` は md のまま）

`context.html` のフォーマットは [assets/context-template.html](./assets/context-template.html) を参照。該当しないセクション（例: ローカルモード時の PR 情報、PR モード時のローカル成果物）は省略してよい。

### 4. Claude Code レビューと Codex レビューの並列実行

**1 メッセージ内で 2 つのレビューを並列発行する**（逐次実行しない）。

#### 4-A. Claude Code レビュー（Agent ツールで `general-purpose` を起動）

`subagent_type = general-purpose` で Agent を 1 つ起動する。プロンプトは以下:

```
あなたはコードレビュアーです。以下の入力ファイルを Read してから、全観点を網羅したレビューを実施し、結果を output-path に HTML で Write してください。

## 入力ファイル
- diff-path: <output-dir 絶対パス>/diff.patch
- context-path: <output-dir 絶対パス>/context.html

## 出力先
- output-path: <output-dir 絶対パス>/review-claude.html

## レビュー観点（全てを網羅的に見る）

<review-perspectives>

## 手順

1. `diff-path` を Read して差分を取得（`gh` / `git` を自分で叩かない）
2. `context-path` を Read して PR / Issue / 既存成果物の要約を把握
3. diff に現れた変更ファイルごとに、コードベースの該当箇所を Read / Grep で深掘りし、上記全観点でレビュー
4. 結果を `output-path` に HTML で Write して保存

## 出力フォーマット

HTML で以下のセクションを `<h2>` 等の見出しで含める:

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
```

パスは**絶対パス**で渡す（エージェントの CWD が親と一致する保証がないため）。`<review-perspectives>` には本 SKILL.md 冒頭の「レビュー観点」セクションの表を**そのまま転記して**展開する（観点表の定義は 1 箇所に保つため、プロンプト内には重複記載しない）。

#### 4-B. Codex レビュー（Skill ツールで `/codex-review` を起動）

`Skill` ツールで `codex-review` を呼び出す。`args` には `$ARGUMENTS` をそのまま渡す（PR 番号 / URL / 空文字列）。Codex は内部で差分取得・情報収集・全観点レビューを行い、以下のいずれかに `review-codex.html` を出力する:

- PR モード: `tmp/prs/<PR 番号>/review-codex.html`
- ローカルモード: `tmp/issues/<issue 番号>/review-codex.html`

#### 並列発行の方法

同一メッセージ内で `Agent` ツール（4-A）と `Skill` ツール（4-B）を同時に発行する。両者の完了を待ってから次のステップへ進む。

### 5. 結果の統合

Claude Code レビュー（`review-claude.html`）と Codex レビュー（`review-codex.html`）の両方を Read し、`<output-dir>/review.html` に **HTML** として統合する。

統合時のルール:

- **概要**: PR / Issue の概要と変更の骨子（`context.html` を参照）
- **良い点**: 両レビュアーから上がった良い点を集約し重複を排除
- **指摘事項**: 重要度別（must / should / nit）にまとめる。各指摘に **レビュアータグ**（`claude` / `codex`）を付与。同じ指摘が両方から上がっている場合は統合し、レビュアータグを両方付ける（**両者が独立に指摘 = 確度が高い**として強調表示）。各指摘に観点タグも併記
- **まとめ**: 総合判断（マージ可否、ブロッカーの有無）。Claude / Codex の指摘傾向の違い（観点の偏り、見落としの差）にも触れてよい

HTML を採用する理由: 重要度の色分け（must=赤 / should=黄 / nit=灰）・レビュアー別バッジ・両者一致指摘の強調・`<details>` 折りたたみなど、Markdown では困難な表現を使うため。

統合後の `review.html` は以下のセクションを `<h2>` 等の見出しで含める（テンプレートは置かない）:

- **概要**
- **サマリ**（must / should / nit の件数、両者一致の件数、Claude のみ / Codex のみの件数）
- **良い点**
- **指摘事項**（must / should / nit を `<h3>` で分け、各指摘にレビュアータグ + 観点タグ）
- **まとめ**

### 6. ユーザーへの提示

`review.html` のサマリ（各重要度の件数、両者一致の件数、ブロッカー概要、総合判断）をユーザーに提示する。詳細は `review-claude.html` と `review-codex.html` を参照するよう案内する。

`<output-dir>/diff.patch` と `<output-dir>/context.html` は中間成果物として残す（後から再確認や再実行のため）。不要なら手動で削除する。

## 注意事項

- Claude Code と Codex は **独立した視点** として並列で動かす。双方とも全観点を見るが、相互に結果を参照させない（独立性を保つことで見落としを相互補完する）
- 指摘には必ず該当ファイルと行番号を含める
- 指摘ごとに重要度（must / should / nit）を付与する
- 良い点も積極的にコメントする
- 軽微なスタイルの指摘はリンターに任せ、レビューでは扱わない
- 両レビュアーが同じ指摘を独立に挙げた場合は確度が高いとみなし、統合後のレビューで強調する

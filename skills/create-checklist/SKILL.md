---
name: create-checklist
description: research の受け入れ条件と plan を起点に、動作確認チェックリストを作成する。
allowed-tools: Bash, Read, Glob, Grep, Write, Task
---

GitHub issue ( $ARGUMENTS ) から動作確認チェックリストを作成する。`$ARGUMENTS` は issue 番号（`123`、`#123`）または URL。

## 手順

1. `tmp/issues/<issue番号>/` 配下の以下を読み込む
   - `research.md`: **受け入れ条件**（AC）— チェックリストの起点となる
   - `plan.md`: 実装計画（タスクと AC カバレッジ）— 各 AC を検証する具体的な操作手順を組み立てる材料
2. `research.md` が無い場合のみ `gh issue view` で issue を取得し、AC を抽出する（`/research` を先に実行することが望ましいが fallback として動く）
3. `git log main..HEAD --stat` でコミット単位の変更概要を確認し、必要に応じて `git show <hash>` で個別のコミット内容を把握する
4. 各 AC を起点に動作確認項目を組み立てる
   - 各 AC を満たすことを確認するための具体的なブラウザ操作・期待結果を記述
   - AC ごとに **正常系・異常系・エッジケース** を網羅する（AC が「不正入力でエラー」なら、各種不正パターンを列挙）
   - チェックリスト項目には対応する AC 番号を併記する（例: `[AC1] 不正なメールでエラーが表示される`）
5. AC で明示的にカバーされていないが動作確認が必要な観点（パフォーマンス・他機能への影響・UI 崩れなど）も補助項目として追加する
6. 結果を Write ツールで `tmp/issues/<issue番号>/checklist.md` に書き込む（フォーマットは [template.md](./assets/template.md) を参照）

## 注意事項

- AC をカバーしないチェック項目は原則作らない（AC こそが「動作する」の定義）。例外は補助項目として明示
- AC が曖昧で確認項目に落とし込めない場合は、ユーザーに確認を取る
- コードベースが大きい場合、調査は issue に関連する部分に絞る

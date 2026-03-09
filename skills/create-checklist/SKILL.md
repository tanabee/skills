---
name: create-checklist
description: GitHub issue から受け入れテスト用の動作確認チェックリストを作成する。
allowed-tools: Bash, Read, Glob, Grep, Write, Task
---

GitHub issue ( $ARGUMENTS ) から動作確認チェックリストを作成する。`$ARGUMENTS` は issue 番号（`123`、`#123`）または URL。

1. `tmp/issues/<issue番号>/plan.md` が既にある場合はその内容を確認し、実装計画を踏まえたチェックリストを作成する
2. `gh issue view` で issue を取得する
3. issue の目的・要件・受け入れ条件を分析する
4. `git log main..HEAD --stat` でコミット単位の変更概要を確認し、必要に応じて `git show <hash>` で個別のコミット内容を把握する
5. 正常系・異常系・エッジケースを網羅した動作確認チェックリストを作成する
5. 結果を Write ツールで `tmp/issues/<issue番号>/checklist.md` に書き込む（フォーマットは [sample.md](./examples/sample.md) を参照）

## 注意事項

- issue の内容が曖昧で確認項目に落とし込めない部分がある場合は、ユーザーに確認を取る
- コードベースが大きい場合、調査は issue に関連する部分に絞る

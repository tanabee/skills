---
name: plan
description: GitHub issue からコードベースを調査し実装計画を作成する。
allowed-tools: Bash, Read, Glob, Grep, Write, Task
---

GitHub issue ( $ARGUMENTS ) から実装計画を作成する。`$ARGUMENTS` は issue 番号（`123`、`#123`）または URL。

1. `tmp/issues/<issue番号>/research.md` が存在する場合は内容を読み込み、調査結果（影響範囲、実装候補、ユーザーの選択など）を計画策定のインプットとして活用する
2. `gh issue view` で issue を取得する
3. issue の目的・要件・受け入れ条件を分析する
4. コードベースを調査し、実装方法の候補を 3 つ程度洗い出す（research.md がある場合はその調査結果をベースに深掘りする）
5. 各候補の概要・メリット・デメリットを提示し、ユーザーに選択してもらう（自由入力でのフィードバックも受け付ける。research.md でユーザーが既に選択済みの場合はそれを尊重する）
6. 選択された方法をもとに、TDD（Red → Green → Refactor）の流れで実装計画を立てる
   - 各タスクは「テストを書く（Red）→ 実装する（Green）→ `/simplify` でリファクタリングする（Refactor）」の順で構成する
   - 各タスクの影響範囲（対象ファイル・関数）、具体的な変更内容、完了条件を特定する
7. 結果を Write ツールで `tmp/issues/<issue番号>/plan.md` に書き込む（フォーマットは [template.md](./assets/template.md) を参照）

## 注意事項

- issue の内容が曖昧で計画に落とし込めない部分がある場合は、ユーザーに確認を取る
- コードベースが大きい場合、調査は issue に関連する部分に絞る

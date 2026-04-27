# Issue タイトル

> Issue: #123 https://github.com/owner/repo/issues/123

## 概要

issue の目的と背景を簡潔に記述する。

## 選択された実装方法

`research.md` の候補から選択した方法を記述する。

- **方法**: 方法 1: 既存の通知サービスを拡張する
- **選択理由**: 呼び出し元の変更が最小限で済み、影響範囲を限定できる。ユーザーフィードバック「今回はスコープを小さく保ちたい」を反映

## 受け入れ条件カバレッジ

`research.md` の各 AC が、どのタスクで満たされるかを明示する。

| AC | 内容 | 対応タスク |
|---|---|---|
| AC1 | 不正なメールアドレスを入力した場合にエラーメッセージが表示される | タスク 1, 2 |
| AC2 | 正常なメールアドレスを入力した場合にエラーが発生しない | タスク 1 |
| AC3 | メールアドレス未入力時に必須項目エラーが表示される | タスク 1 |

## 副作用 identifier

この計画が引き起こす間接依存の起点となる identifier を列挙する。空の場合はその旨を明記する。

- 書き込み: Firestore `orders/{orderId}`, `users/{uid}/notifications/*`
- 発火: イベント `order.placed`
- 設定: feature flag `enable_new_checkout`

### 想定される波及先

- `functions/src/triggers/onOrderWrite.ts` が発火 → 受注通知送信
- `analytics/orders/*` への集計書き込み

## タスク

- [ ] 1. ユーザー入力のバリデーション追加
- [ ] 2. エラーハンドリングの実装

## 詳細

### 1. ユーザー入力のバリデーション追加

- 影響範囲: `src/validators/user.ts`, `tests/validators/user.test.ts`

#### Red: テストを書く

- 対象ファイル: `tests/validators/user.test.ts`
- 変更内容:
  - 不正なメールアドレスで `ValidationError` がスローされるテストを追加する
  - 正常なメールアドレスでエラーが発生しないテストを追加する
- 完了条件: テストが失敗すること（実装がまだないため）

#### Green: 実装する

- 対象ファイル: `src/validators/user.ts`, `src/controllers/user.ts`
- 変更内容:
  - `src/validators/user.ts` に `validateEmail()` を新規作成する
  - `src/controllers/user.ts` の `createUser()` 内で `validateEmail()` を呼び出す
- 完了条件: Red で書いたテストが全て通ること

#### Refactor: `/simplify` でリファクタリングする

- リファクタリング観点: バリデーションロジックの共通化、命名の改善など
- 完了条件: テストが引き続き全て通ること

- 依存タスク: なし

### 2. エラーハンドリングの実装

- 影響範囲: `src/middleware/error.ts`, `tests/middleware/error.test.ts`

#### Red: テストを書く

- 対象ファイル: `tests/middleware/error.test.ts`
- 変更内容:
  - `ValidationError` 発生時に 400 ステータスとエラーメッセージが返るテストを追加する
- 完了条件: テストが失敗すること（実装がまだないため）

#### Green: 実装する

- 対象ファイル: `src/middleware/error.ts`
- 変更内容:
  - `src/middleware/error.ts` で `ValidationError` をキャッチし 400 レスポンスを返す
- 完了条件: Red で書いたテストが全て通ること

#### Refactor: `/simplify` でリファクタリングする

- リファクタリング観点: エラーハンドリングパターンの統一など
- 完了条件: テストが引き続き全て通ること

- 依存タスク: 1

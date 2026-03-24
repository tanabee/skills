# Issue タイトル

> Issue: #123 https://github.com/owner/repo/issues/123

## 概要

issue の目的と背景を簡潔に記述する。

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

# Issue タイトル

> Issue: #123 https://github.com/owner/repo/issues/123

## 概要

issue の目的と背景を簡潔に記述する。

## タスク

- [ ] 1. ユーザー入力のバリデーション追加
- [ ] 2. エラーハンドリングの実装
- [ ] 3. テストの追加

## 詳細

### 1. ユーザー入力のバリデーション追加

- 影響範囲: `src/validators/user.ts`, `src/controllers/user.ts`
- 変更内容:
  - `src/validators/user.ts` に `validateEmail()` を新規作成する
  - `src/controllers/user.ts` の `createUser()` 内で `validateEmail()` を呼び出す
- 完了条件: 不正なメールアドレスで `ValidationError` がスローされること
- 依存タスク: なし

### 2. エラーハンドリングの実装

- 影響範囲: `src/middleware/error.ts`, `src/controllers/user.ts`
- 変更内容:
  - `src/middleware/error.ts` で `ValidationError` をキャッチし 400 レスポンスを返す
- 完了条件: バリデーションエラー時に 400 ステータスとエラーメッセージが返ること
- 依存タスク: 1

### 3. テストの追加

- 影響範囲: `tests/validators/user.test.ts`, `tests/controllers/user.test.ts`
- 変更内容:
  - 正常系・異常系のテストケースを追加する
- 完了条件: テストが全て通ること
- 依存タスク: 1, 2

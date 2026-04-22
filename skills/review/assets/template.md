# PR レビュー

> PR: #45 https://github.com/owner/repo/pull/45
> 関連 Issue: #123

## 概要

ユーザー登録時のメールバリデーションを追加する PR。`src/validators/user.ts` にバリデーション関数を新設し、コントローラーから呼び出す構成。

## 良い点
- バリデーションロジックがコントローラーから分離されており、テスタビリティが高い
- エラーメッセージが具体的でユーザーフレンドリー

## 指摘事項

### must

- **`src/validators/user.ts:15`** — `validateEmail()` が `null` を受け取った場合に `TypeError` がスローされる。引数の null チェックを追加すべき
  ```ts
  // 修正案
  function validateEmail(email: string | null): boolean {
    if (!email) return false;
    // ...
  }
  ```

### should

- **`src/controllers/user.ts:42-48`** — `try-catch` ブロックで `ValidationError` 以外の例外もキャッチしている。予期しないエラーが握りつぶされる可能性がある
  ```ts
  // 修正案: ValidationError のみキャッチする
  catch (error) {
    if (error instanceof ValidationError) {
      return res.status(400).json({ message: error.message });
    }
    throw error;
  }
  ```

- **`tests/validators/user.test.ts`** — 国際化ドメイン（例: `user@例え.jp`）のテストケースがない。要件として不要であれば、その旨をコメントに残すと良い

### nit

- **`src/validators/user.ts:3`** — `EMAIL_REGEX` は `src/constants/` に定義済みの正規表現と重複している。既存の定数を再利用できる

## まとめ

全体として設計は良好。`null` ハンドリングの修正（must）を対応すればマージ可能と判断します。

---
name: nanobanana
description: Gemini の画像生成モデル (nanobanana) で画像を生成する。`gemini-3.1-flash-image-preview` (デフォルト) と `gemini-3-pro-image-preview` に対応。
allowed-tools: Bash, Read, Write, AskUserQuestion
---

Gemini の画像生成モデルで画像を生成し `tmp/images/` に保存する。API キーは環境変数 `GEMINI_API_KEY` を使用する。

パラメータの enum・モデル別の対応状況は [assets/parameters.md](./assets/parameters.md) を参照。curl サンプルは [assets/flash.sh](./assets/flash.sh) / [assets/pro.sh](./assets/pro.sh)。

1. `$ARGUMENTS` から **プロンプト本文** と以下のオプションを抽出する。プロンプトが空ならユーザーに質問する
    - `--model` (`flash`=デフォルト | `pro` | 任意のモデル ID) / `--aspect` / `--size` (デフォルト `1K`) / `--person` / `--thinking` (Flash のみ)
2. 実行ごとに一意の ID を作る（例: `ID=$(date +%Y%m%d-%H%M%S)-$$`）。中間ファイルは `tmp/images/${ID}.request.json` / `tmp/images/${ID}.response.json` のように ID 付きで扱い、並列実行時の衝突を防ぐ
3. 選択したモデルの curl サンプルをベースに、`INSERT_INPUT_HERE` をプロンプト（JSON エスケープ済み）に、`imageConfig` の各フィールドを指定値に差し替えて `tmp/images/${ID}.request.json` を生成する。Pro では `thinkingConfig` を含めない
4. `curl -sS -X POST -H "Content-Type: application/json" "https://generativelanguage.googleapis.com/v1beta/models/${MODEL_ID}:streamGenerateContent?key=${GEMINI_API_KEY}" -d @tmp/images/${ID}.request.json -o tmp/images/${ID}.response.json` を実行
5. レスポンス（JSON 配列）の `candidates[].content.parts[].inlineData` から base64 画像を取り出し、mimeType に応じた拡張子で `tmp/images/${ID}.<ext>` に保存する。`parts[].text` があれば報告に含める
6. 使用モデル・保存パス・テキスト応答をユーザーに報告する。`error` フィールドがあれば内容を報告

## 注意事項

- `GEMINI_API_KEY` 未設定時は `export` を案内して中断。API キーをログに出力しない
- プロンプトは JSON エスケープする（`jq -Rs` や heredoc + `jq` を推奨）
- 生成画像には SynthID ウォーターマークが自動付与される

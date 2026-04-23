# Gemini 画像生成モデル パラメータ仕様

出典: [Gemini 3 docs](https://ai.google.dev/gemini-api/docs/gemini-3) / [Image generation docs](https://ai.google.dev/gemini-api/docs/image-generation) / [Models](https://ai.google.dev/gemini-api/docs/models)

## モデル一覧

| エイリアス | モデル ID | 通称 | 特徴 | 料金（参考） |
|-----------|-----------|------|------|-------------|
| `flash` | `gemini-3.1-flash-image-preview` | Nano Banana 2 | 高スループット・低コスト。`thinkingConfig` 対応。Google Image Search グラウンディング対応 | $0.25 text input / $0.067 image output |
| `pro` | `gemini-3-pro-image-preview` | Nano Banana Pro | 4K・複雑なレイアウト・テキスト描画に強い。`thinkingConfig` 非対応 | $2 text input / $0.134 image output |

## `aspectRatio`

| 値 | Flash | Pro |
|----|:----:|:----:|
| `1:1` | ✅ | ✅ |
| `2:3` | ✅ | ✅ |
| `3:2` | ✅ | ✅ |
| `3:4` | ✅ | ✅ |
| `4:3` | ✅ | ✅ |
| `4:5` | ✅ | ✅ |
| `5:4` | ✅ | ✅ |
| `9:16` | ✅ | ✅ |
| `16:9` | ✅ | ✅ |
| `21:9` | ✅ | ✅ |
| `1:4` | ✅ | ❌ |
| `4:1` | ✅ | ❌ |
| `1:8` | ✅ | ❌ |
| `8:1` | ✅ | ❌ |

空文字 `""` を指定するとモデル任せ。

## `imageSize`

| 値 | Flash | Pro | 備考 |
|----|:----:|:----:|------|
| `512` | ✅ | ❌ | `K` なし |
| `1K` | ✅ | ✅ | デフォルト |
| `2K` | ✅ | ✅ | |
| `4K` | ✅ | ✅ | Pro はテキスト描画に強い |

## `personGeneration`

| 値 | 説明 |
|----|------|
| `allow_all` | 人物（成人・子供含む）生成を許可 |
| `allow_adult` | 成人のみ許可 |
| `dont_allow` | 人物生成を不許可 |

空文字 `""` を指定するとモデル任せ。地域によって利用できる値が異なる場合がある。

## `responseModalities`

- `["IMAGE", "TEXT"]` : 画像とテキストの両方を返す（本スキルのデフォルト）
- `["IMAGE"]` : 画像のみ

## `thinkingConfig`（Flash のみ）

Pro では **このフィールドごと付与しない**。Flash では thinking はデフォルトで有効、無効化は不可。

| フィールド | 値 | 説明 |
|-----------|----|------|
| `thinkingLevel` | `MINIMAL`（デフォルト）/ `HIGH` | 思考の深さ |
| `includeThoughts` | boolean（デフォルト `false`） | 応答に思考内容を含めるか |

## 参照画像（multi-image editing）

入力画像で編集・合成する際の上限。

| モデル | オブジェクト | キャラクター | 合計 |
|--------|:----------:|:-----------:|:---:|
| Flash | 10 | 4 | 14 |
| Pro | 6 | 5 | 14 |

## コンテキストウィンドウ

| モデル | 入力 | 出力 |
|--------|-----:|-----:|
| Flash | 128k tokens | 32k tokens |
| Pro | （ドキュメント未記載） | - |

## その他

- 生成画像には **SynthID ウォーターマーク** が自動付与される
- Gemini 3 系ではピクセル単位のセグメンテーションマスクは非対応（必要なら Gemini 2.5 Flash を使う）
- 会話形式の編集（multi-turn editing）では、レスポンスの `thoughtSignature` をそのまま次のリクエストに引き継ぐ必要がある

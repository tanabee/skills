---
name: open-file
description: 指定されたファイルを種別に応じた最適なアプリで開くスキル。Markdown (.md) は grip で GitHub 風にレンダリングしてブラウザ表示、HTML は `open` でデフォルトブラウザ表示、その他は Antigravity IDE で開く。ユーザーが「このファイル開いて」「〜をブラウザで見たい」「〜をプレビューして」などファイルを開く・見る・表示する意図を示したら必ず使用する。
allowed-tools: Bash
---

指定されたファイルを拡張子に応じて開き分ける。相対パスは絶対パスに解決してから使う。ファイルが見つからない場合は近い名前をプロジェクト内から検索し、候補が複数あればユーザーに確認する。

## 開き分けルール

| 拡張子 | 開き方 |
|---|---|
| `.md` `.markdown` | grip でレンダリングしてブラウザ表示 |
| `.html` `.htm` | `open <path>` (デフォルトブラウザ) |
| その他すべて | Antigravity IDE |

ユーザーが開き方を明示した場合 (「IDE で開いて」等) はそちらを優先する。

## Markdown: grip

grip は GitHub API でレンダリングするローカルサーバ。フォアグラウンドで動き続けるためバックグラウンドで起動する。

```bash
# 既に同ファイルを配信中の grip があればそのまま URL を開くだけでよい
pgrep -fl "grip" || true

# 空きポートを選んで起動 (デフォルト 6419 が使用中なら 6420, 6421... とずらす)
grip -b "<absolute-path>" 6419
```

- `-b` で起動時にブラウザが自動で開く
- 起動後はサーバをそのまま残してよい (ユーザーがリロードで再閲覧できる)。同一ポートで別ファイルを開きたい場合は既存 grip を kill してから起動する
- GitHub API のレート制限 (未認証 60 req/h) に当たったらその旨を伝え、代替として Antigravity IDE で開くことを提案する

## その他: Antigravity IDE

CLI は PATH に無いのでフルパスで呼ぶ。行番号指定 (`file:line`) にも対応。

```bash
AGY_IDE="/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide"
"$AGY_IDE" --goto "<absolute-path>:<line>"   # 行番号があるとき
"$AGY_IDE" "<absolute-path>"                 # 通常
```

CLI が失敗する場合のフォールバック: `open -a "Antigravity IDE" "<absolute-path>"`

## 完了報告

開いたファイルのパスと開き方 (grip の場合は URL) を 1 行で報告する。

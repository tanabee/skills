---
name: open
description: 指定されたファイルやフォルダを種別に応じた最適なアプリで開くスキル。Markdown (.md) は grip で GitHub 風にレンダリングしてブラウザ表示、HTML はブラウザ表示 (config でテスト用ブラウザ・プロファイルを指定。未設定なら初回に質問して保存)、フォルダは `open` で Finder 表示、その他は Antigravity IDE で開く。ユーザーが「このファイル開いて」「〜をブラウザで見たい」「〜をプレビューして」などファイルやフォルダを開く・見る・表示する意図を示したら必ず使用する。
allowed-tools: Bash, AskUserQuestion
---

指定されたファイルやフォルダを種別に応じて開き分ける。相対パスは絶対パスに解決してから使う。対象が見つからない場合は近い名前をプロジェクト内から検索し、候補が複数あればユーザーに確認する。

## 開き分けルール

| 対象 | 開き方 |
|---|---|
| フォルダ | `open <path>` (Finder) |
| `.md` `.markdown` | grip でレンダリングしてブラウザ表示 |
| `.html` `.htm` | ブラウザ表示 (下記「ブラウザの決定」) |
| その他すべて | Antigravity IDE |

ユーザーが開き方を明示した場合 (「IDE で開いて」「デフォルトブラウザで開いて」等) はそちらを優先する。

## ブラウザの決定 (config.json)

ブラウザで開く前に、以下の順で config を探し、最初に見つかった `browser` を使う。

1. プロジェクト (git root) の `.agents/skills-config/open/config.json`
2. ユーザーの `~/.agents/.skills-config/open/config.json`

```json
{
  "browser": {
    "command": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "args": [
      "--user-data-dir=/Users/<me>/.cache/chrome-devtools-mcp/profiles/<project>-artifacts",
      "--no-first-run",
      "--no-default-browser-check"
    ]
  }
}
```

- `command`: ブラウザの実行ファイル。`open -a` は起動済みアプリに引数を渡せないため、バイナリを直接指定する
- `args`: 起動引数。`--user-data-dir` をメインブラウザと別にすると、メインの Chrome が起動中でも独立インスタンスとして立ち上がり、成果物のタブがメインブラウザに混ざらない (同じ dir への 2 回目以降の呼び出しは既存インスタンスにタブ追加される)。`~` は展開されないので絶対パスで書く
- デフォルトブラウザを使う場合は `"browser": "default"` と書く

### 未設定時: 質問して保存する (黙ってフォールバックしない)

どちらにも `browser` が無い場合、**AskUserQuestion で開き方を確認し、回答を config に保存してから開く**。保存先はプロジェクト (git root) の config。git 管理外なら ユーザーの config。以降の呼び出しは保存した設定を使うので、質問は初回の 1 回だけになる。

選択肢:

- **テスト用 Chrome プロファイルで開く (推奨)**: 上記例の形で保存する。`--user-data-dir` は `~/.cache/chrome-devtools-mcp/profiles/<プロジェクト名>-artifacts` を既定にし、既存プロファイル (`ls ~/.cache/chrome-devtools-mcp/profiles`) があれば選択肢に加える
- **デフォルトブラウザで開く**: `{"browser": "default"}` を保存する

ユーザーがその場で開き方を明示した場合 (「デフォルトブラウザで開いて」等) は質問せずそれに従い、config は変更しない。

### 開き方

- `browser` が `"default"`: `open <path or URL>`
- `browser` がオブジェクト (ファイルは `file://` URL にする):

```bash
nohup "<command>" <args...> "<file://absolute-path または URL>" >/dev/null 2>&1 &
```

## Markdown: grip

grip は GitHub API でレンダリングするローカルサーバ。フォアグラウンドで動き続けるためバックグラウンドで起動する。

```bash
# 既に同ファイルを配信中の grip があればそのまま URL を開くだけでよい
pgrep -fl "grip" || true

# 空きポートを選んで起動 (デフォルト 6419 が使用中なら 6420, 6421... とずらす)
# browser が "default": -b で起動時にデフォルトブラウザが自動で開く
grip -b "<absolute-path>" 6419

# browser がオブジェクト: -b を付けず、起動を待ってから URL を「ブラウザの決定」の方法で開く
grip "<absolute-path>" 6419 >/dev/null 2>&1 &
for i in $(seq 1 20); do curl -s -o /dev/null http://localhost:6419 && break; sleep 0.5; done
nohup "<command>" <args...> "http://localhost:6419" >/dev/null 2>&1 &
```

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

開いたファイルのパスと開き方 (grip の場合は URL、config のブラウザなら「テスト用ブラウザ」と分かるように) を 1 行で報告する。

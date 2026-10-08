---
name: open
description: 指定されたファイルやフォルダを種別に応じた最適なアプリで開くスキル。Markdown (.md) は grip で GitHub 風にレンダリングしてブラウザ表示、HTML はブラウザ表示 (config でテスト用ブラウザ・プロファイルを指定。未設定なら初回に質問して保存。同じ URL のタブが開いていれば新規タブを増やさずリロード)、フォルダは `open` で Finder 表示、その他は Antigravity IDE で開く。ユーザーが「このファイル開いて」「〜をブラウザで見たい」「〜をプレビューして」などファイルやフォルダを開く・見る・表示する意図を示したら必ず使用する。
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
      "--remote-debugging-port=0",
      "--allow-file-access-from-files",
      "--no-first-run",
      "--no-default-browser-check"
    ]
  }
}
```

- `command`: ブラウザの実行ファイル。`open -a` は起動済みアプリに引数を渡せないため、バイナリを直接指定する
- `args`: 起動引数。`--user-data-dir` をメインブラウザと別にすると、メインの Chrome が起動中でも独立インスタンスとして立ち上がり、成果物のタブがメインブラウザに混ざらない (同じ dir への 2 回目以降の呼び出しは既存インスタンスにタブ追加される)。`~` は展開されないので絶対パスで書く
- `--remote-debugging-port=0`: 「既存タブがあればリロード」(下記「開き方」)に必要。**ポートは必ず `0`**(OS が空きポートを割り当て、Chrome が `<user-data-dir>/DevToolsActivePort` に書く)。固定ポートにすると、別 repo の `/dev` を並列実行したとき後から起動した Chrome がポートを取れず、`/open` が別 repo の Chrome にタブを開いてしまう。専用 `--user-data-dir` でのみ有効 (Chrome 136+ は既定プロファイルではこのフラグを無視する)
- `--allow-file-access-from-files`: `/dev` のビューア (`dev/assets/viewer.html`) が同じディレクトリの成果物を `file://` 同士で fetch するために必要。ローカル HTML が他のローカルファイルを読める状態になるので、**成果物閲覧専用のプロファイルにだけ付け、普段使いの Chrome には付けない**
- デフォルトブラウザを使う場合は `"browser": "default"` と書く

### 既存 config の移行

`browser` がオブジェクトで、`args` に `--remote-debugging-port=0` または `--allow-file-access-from-files` が無い場合は、**この 2 つを `args` に足して(`--remote-debugging-port=<固定値>` があれば `0` に書き換えて)保存してから開く**(質問はしない)。追記した旨と、その `--user-data-dir` で既に起動している Chrome があれば「一度終了すると以降は既存タブのリロードになる」ことを 1 行で伝える。

### 開き方

- `browser` が `"default"`: `open <path or URL>`
- `browser` がオブジェクト (ファイルは `file://` URL にする): **同じ URL のタブが既に開いていればリロード、無ければ新規タブ**。`args` の `--user-data-dir=<dir>` を読み、以下の順で試す

```bash
CDP="<このスキルのディレクトリ>/assets/cdp.mjs"   # SKILL.md と同じ階層の assets/
URL="file://<absolute-path>"                      # #fragment 付きでもよい
if node "$CDP" "<user-data-dir>" open "$URL"; then
  :                                              # 同 URL → 前面化してリロード / ハッシュだけ違う → ハッシュ遷移 / 無し → 新規タブ
elif pgrep -f -- "--user-data-dir=<user-data-dir>" >/dev/null; then
  nohup "<command>" <args...> "$URL" >/dev/null 2>&1 &   # 旧引数で起動中: 新規タブで妥協し、「その Chrome を一度終了すると次回からリロードになる」と伝える
else
  nohup "<command>" <args...> "$URL" >/dev/null 2>&1 &   # 未起動: 初回起動 (Chrome が DevToolsActivePort を書き、以降は接続できる)
fi
```

- `cdp.mjs` は `<user-data-dir>/DevToolsActivePort` からポートを読んで接続する (Node 22+ 標準の WebSocket だけで動く。依存なし)。接続できなければ終了コード 2 を返す (未起動、または前回起動時のファイルの残骸)。`node cdp.mjs <user-data-dir> list` でタブ一覧を確認できる
- 同じ HTML を何度開き直しても (例: `/dev` のループで plan.html が再生成される場合) タブは増えない。ハッシュだけ違う URL (`viewer.html#plan` → `#report`) はリロードせずページ内遷移になる
- **別 repo の `/dev` を並列実行する場合**: repo ごとに `--user-data-dir` を分ける (既定の `<プロジェクト名>-artifacts` で分かれる)。ポートはプロファイルごとに自動割当なので衝突せず、`/open` は自分の repo の Chrome だけを操作する。複数 repo で同じプロファイルを共用すると同じウィンドウにタブが並ぶが、URL が成果物ディレクトリを含むため取り違えは起きない

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

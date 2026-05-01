---
name: browser
description: chrome-devtools-mcp の CLI (`chrome-devtools`) を使ったブラウザ操作の総合スキル。既存ブラウザに attach するかテスト用ブラウザを起動するかをユーザーに必ず確認した上でサーバを立ち上げ、スナップショット取得・クリック・入力・ナビゲーション・スクショ・ネットワーク監視などを行う。
allowed-tools: Bash, Read, AskUserQuestion
---

`chrome-devtools-mcp` の CLI (`chrome-devtools`) でブラウザを起動し、その後の操作までカバーする。

## 1. 接続先の確認 (毎回必須)

`chrome-devtools status` で状態を確認した後、**起動済みでも未起動でも、必ず AskUserQuestion で接続先をユーザーに確認してから操作に入る**。起動済みサーバが意図と異なる構成のまま使うのは事故の元なので、毎回 `stop` → `start` で整える。

選択肢は **2 つだけ**:

- **既存ブラウザに接続**: いま開いている Chrome に attach。実セッション (ログイン状態・拡張・タブ) を使いたいとき
- **テスト用ブラウザを起動**: 新規 user-data-dir で隔離された Chrome (デフォルト挙動)

### 既存ブラウザに接続

前提: Chrome 144+ で `chrome://inspect/#remote-debugging` の「Allow remote debugging for this browser instance」が ON。

`DevToolsActivePort` から port (1 行目) と WS path (2 行目) を読み、`--wsEndpoint` で接続する:

```bash
# macOS: ~/Library/Application Support/Google/Chrome/DevToolsActivePort
# Linux: ~/.config/google-chrome/DevToolsActivePort
# Windows: $LOCALAPPDATA/Google/Chrome/User Data/DevToolsActivePort

chrome-devtools stop 2>/dev/null
chrome-devtools start --wsEndpoint "ws://127.0.0.1:${PORT}${WS_PATH}"
chrome-devtools list_pages   # 既存タブが見えれば接続成功
```

初回接続時は Chrome 側に承認ダイアログが出ることがある。`list_pages` で既存タブが見えなければユーザーに承認を促す。

`DevToolsActivePort` が読めない場合 (Chrome を `--remote-debugging-port=N` で別プロファイル起動しているケース等) は AskUserQuestion で port を聞く。

### テスト用ブラウザを起動

```bash
chrome-devtools stop 2>/dev/null
chrome-devtools start
chrome-devtools list_pages
```

## 2. AI ワークフロー

1. **Inspect**: `take_snapshot` で要素の `<uid>` を取得
2. **Act**: `click` / `fill` / `navigate_page` 等で操作。状態はコマンド間で永続
3. 操作後の状態が必要なら、各操作コマンドに `--includeSnapshot true` を付ける

接続確立後は同一セッション中サーバが永続するので、都度 `start` / `status` / `stop` を呼ぶ必要はない。

スナップショット例:
```
uid=1_0 RootWebArea "Example Domain" url="https://example.com/"
  uid=1_1 heading "Example Domain" level="1"
```

## 3. コマンドリファレンス

カテゴリ別の使用例は [assets/commands.md](./assets/commands.md) を参照 (Input Automation / Navigation / Emulation / Debugging / Network / Performance / Extensions / Service Management / Experimental)。各コマンドは `--help` で詳細を確認できる。

## 注意事項

- 接続中は Chrome 上に「Chrome is being controlled by automated test software」バナーが表示される
- `navigate_page` の URL 指定は `navigate_page url --url "<URL>"` (positional `type` + `--url`)
- Experimental ツール (`click_at` / `screencast_*` / `list_webmcp_tools`) は `start` 時に該当フラグ (`--experimentalVision` / `--experimentalScreencast` / `--experimentalWebmcp`) が必要

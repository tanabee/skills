# chrome-devtools コマンドリファレンス

`chrome-devtools <tool> [args] [flags]` 形式。`--help` で詳細。出力は Markdown(`--output-format=json` で JSON)。

## Input Automation (uid は `take_snapshot` から取得)

```bash
chrome-devtools take_snapshot                                # a11y ツリーから snapshot 取得
chrome-devtools take_snapshot --verbose true --filePath s.txt
chrome-devtools click "uid"                                  # クリック
chrome-devtools click "uid" --dblClick true                  # ダブルクリック
chrome-devtools fill "uid" "text"                            # input/select に入力
chrome-devtools type_text "hello" --submitKey "Enter"        # フォーカス中要素にキーボード入力
chrome-devtools press_key "Control+A"                        # キー押下
chrome-devtools hover "uid"
chrome-devtools drag "src_uid" "dst_uid"
chrome-devtools upload_file "uid" "file.txt"
chrome-devtools handle_dialog accept                          # ダイアログ受理
chrome-devtools handle_dialog dismiss --promptText "hi"
```

操作系コマンドは `--includeSnapshot true` で操作後の snapshot を返せる。

## Navigation

```bash
chrome-devtools list_pages                                   # タブ一覧
chrome-devtools new_page "https://example.com"
chrome-devtools new_page "https://example.com" --background true --timeout 5000
chrome-devtools select_page 1 --bringToFront true            # 以降の操作対象を変更
chrome-devtools navigate_page --url "https://example.com"
chrome-devtools navigate_page --type "reload" --ignoreCache true
chrome-devtools navigate_page --type "back"
chrome-devtools close_page 1
```

## Emulation

```bash
chrome-devtools emulate --networkConditions "Offline"
chrome-devtools emulate --cpuThrottlingRate 4 --geolocation "0x0"
chrome-devtools emulate --colorScheme "dark" --viewport "1920x1080"
chrome-devtools emulate --userAgent "Mozilla/5.0 ..."
chrome-devtools resize_page 1920 1080
```

## Debugging & Inspection

```bash
chrome-devtools take_screenshot                              # ビューポート
chrome-devtools take_screenshot --fullPage true --format jpeg --quality 80
chrome-devtools take_screenshot --uid "uid" --filePath s.png # 要素単体
chrome-devtools evaluate_script "() => document.title"
chrome-devtools evaluate_script "(a) => a.innerText" --args 1_4   # uid を引数化
chrome-devtools list_console_messages --types error --types info
chrome-devtools get_console_message 1
chrome-devtools lighthouse_audit --mode "navigation"
chrome-devtools lighthouse_audit --mode "snapshot" --device "mobile" --outputDirPath ./out
```

## Network

```bash
chrome-devtools list_network_requests --pageSize 50 --resourceTypes Fetch
chrome-devtools list_network_requests --includePreservedRequests true
chrome-devtools get_network_request --reqid 1 --requestFilePath req.md --responseFilePath res.md
```

## Performance

```bash
chrome-devtools performance_start_trace true true --filePath t.gz
chrome-devtools performance_stop_trace --filePath t.json
chrome-devtools performance_analyze_insight "1" "LCPBreakdown"
chrome-devtools take_memory_snapshot ./snap.heapsnapshot
```

## Extensions

```bash
chrome-devtools list_extensions
chrome-devtools install_extension /path/to/extension
chrome-devtools uninstall_extension <extension_id>
chrome-devtools reload_extension <extension_id>
chrome-devtools trigger_extension_action <extension_id>
```

## Service Management (通常不要)

```bash
chrome-devtools status   # 稼働確認
chrome-devtools start    # 起動 / 再起動
chrome-devtools stop     # 停止
```

## Experimental

`start` 時に該当フラグを付けたときのみ有効。

```bash
chrome-devtools click_at 100 200            # --experimentalVision=true
chrome-devtools screencast_start            # --experimentalScreencast=true (要 ffmpeg)
chrome-devtools screencast_stop
chrome-devtools list_webmcp_tools           # --experimentalWebmcp=true
```

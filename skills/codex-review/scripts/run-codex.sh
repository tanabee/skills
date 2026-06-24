#!/bin/bash
# run-codex.sh - codex exec を非対話・強制実行で起動する薄いラッパー
#
# Usage:
#   run-codex.sh <prompt_file>
#
# Why a shell wrapper:
#   - プロンプトを引数に直接渡すとシェルメタ文字でクォートが壊れやすく、
#     Claude Code の Bash 許可リストにも乗りにくい。ファイル経由にすると
#     コマンドラインが固定化され、許可も安定する。
#   - `</dev/null` で stdin を閉じることで、`codex exec` が稀に stdin
#     待ちでハングするのを防ぐ。
#   - `--dangerously-bypass-approvals-and-sandbox` を必ず付けて、
#     review skill から並列呼び出しされた際の承認プロンプト停止を回避する。

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <prompt_file>" >&2
  exit 1
fi

PROMPT_FILE="$1"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI is required but not installed. Run: npm install -g @openai/codex" >&2
  exit 1
fi

trap 'rm -f "$PROMPT_FILE"' EXIT

PROMPT=$(cat "$PROMPT_FILE")
if [ -z "$PROMPT" ]; then
  echo "ERROR: prompt file is empty: $PROMPT_FILE" >&2
  exit 1
fi

exec codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT" </dev/null

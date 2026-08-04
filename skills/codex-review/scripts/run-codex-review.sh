#!/bin/sh
# run-codex-review.sh - Codex 公式プラグイン (codex@openai-codex) の companion runtime で
# Codex ネイティブレビューを起動する薄いラッパー
#
# Usage:
#   run-codex-review.sh [--cwd <dir>] [--base <ref>] [--scope auto|working-tree|branch]
#
# Why a shell wrapper:
#   - プラグインの実体パスはバージョン付きディレクトリ
#     (~/.claude/plugins/cache/openai-codex/codex/<version>/) にあり、更新で変わる。
#     最新バージョンをここで解決することで SKILL.md 側をパス非依存に保つ。
#   - `</dev/null` で stdin を閉じ、review skill から並列呼び出しされた際の
#     stdin 待ちハングを防ぐ。

set -eu

root=$(ls -d "$HOME"/.claude/plugins/cache/openai-codex/codex/*/ 2>/dev/null | sort -V | tail -n 1)

if [ -z "${root:-}" ]; then
  cat >&2 <<'EOF'
ERROR: codex plugin not found. Install it with:
  /plugin marketplace add openai/codex-plugin-cc
  /plugin install codex@openai-codex
EOF
  exit 1
fi

exec node "${root}scripts/codex-companion.mjs" review "$@" </dev/null

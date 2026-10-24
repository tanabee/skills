#!/bin/sh
# run-codex-review.sh - Codex 公式プラグイン (codex@openai-codex) の companion runtime で
# Codex ネイティブレビュー (デフォルト: gpt-6-astra) を起動する薄いラッパー
#
# Usage:
#   run-codex-review.sh [--cwd <dir>] [--base <ref>] [--model <model>] [--scope auto|working-tree|branch]
#
# Why a shell wrapper:
#   - プラグインの実体パスはバージョン付きディレクトリ
#     (~/.claude/plugins/cache/openai-codex/codex/<version>/) にあり、更新で変わる。
#     最新バージョンをここで解決することで SKILL.md 側をパス非依存に保つ。
#   - mise 経由でインストールされた codex バイナリが、別バージョンの node 配下にあり
#     mise shim で弾かれるケースに備え、実体ディレクトリを PATH に補完する。
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

if ! command -v codex >/dev/null 2>&1 || ! codex --version >/dev/null 2>&1; then
  codex_bin=$(ls "$HOME"/.local/share/mise/installs/node/*/bin/codex 2>/dev/null | sort -V | tail -n 1 || true)
  if [ -n "${codex_bin:-}" ]; then
    PATH="$(dirname "$codex_bin"):$PATH"
    export PATH
  fi
fi

has_model=0
for arg in "$@"; do
  case "$arg" in
    --model|--model=*|-m)
      has_model=1
      break
      ;;
  esac
done

if [ "$has_model" -eq 0 ]; then
  set -- --model gpt-6-astra "$@"
fi

exec node "${root}scripts/codex-companion.mjs" review "$@" </dev/null

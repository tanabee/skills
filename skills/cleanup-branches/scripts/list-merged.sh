#!/usr/bin/env bash
# ローカルブランチをマージ状況で分類して TSV で出力する (削除はしない)。
# usage: list-merged.sh [base-branch|-] [protected-branch...]
# 出力: 1 行目 "base<TAB><比較対象>"、以降 "<status>\t<branch>\t<reason>\t<sha>\t<date>\t<subject>"
#   status: delete (マージ済みと確認) / review (リモート削除済みだがマージ未確認) / skip (チェックアウト中)
#   未マージのブランチ・ベースブランチ・保護ブランチ (main master develop + 引数) は出力しない
set -euo pipefail

base_arg="${1:--}"
[ $# -gt 0 ] && shift
protected=" main master develop $* "

git rev-parse --git-dir >/dev/null
git fetch --prune --quiet origin 2>/dev/null || echo "warn: git fetch に失敗。ローカルの情報で判定する" >&2

if [ "$base_arg" != "-" ]; then
  default="$base_arg"
else
  default=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)
  if [ -z "$default" ]; then
    for c in main master; do
      if git show-ref --verify --quiet "refs/heads/$c"; then default="$c"; break; fi
    done
  fi
fi
[ -n "$default" ] || { echo "error: ベースブランチを特定できない。引数で指定する" >&2; exit 1; }

if git show-ref --verify --quiet "refs/remotes/origin/$default"; then
  base="origin/$default"
else
  base="$default"
fi
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "error: ベースブランチ $base が無い" >&2; exit 1; }
printf 'base\t%s\n' "$base"

# squash / rebase マージの検出: ブランチ全体を 1 コミットに畳んだ差分と同じパッチが base にあるか
is_squashed() {
  local mb tmp
  mb=$(git merge-base "$base" "$1") || return 1
  tmp=$(git commit-tree "$1^{tree}" -p "$mb" -m _) || return 1
  case "$(git cherry "$base" "$tmp")" in "-"*) return 0 ;; esac
  return 1
}

# マージ済み PR の head とローカルの先端が一致するか (gh が使える場合のみ。取得は 1 回)
merged_prs=""
merged_prs_loaded=0
is_merged_pr() {
  if [ "$merged_prs_loaded" = 0 ]; then
    merged_prs_loaded=1
    merged_prs=$(gh pr list --state merged --limit 300 --json headRefName,headRefOid \
      --jq '.[] | .headRefName + " " + .headRefOid' </dev/null 2>/dev/null || true)
  fi
  printf '%s\n' "$merged_prs" | grep -qxF "$1 $2"
}

sep=$'\x1f'
git for-each-ref refs/heads \
  --format='%(refname:short)%1f%(objectname)%1f%(upstream:track)%1f%(worktreepath)%1f%(committerdate:short)%1f%(subject)' |
while IFS="$sep" read -r br sha track wt date subj; do
  status=keep
  reason=""
  if git merge-base --is-ancestor "$sha" "$base"; then
    status=delete; reason="merged"
  elif is_squashed "$br"; then
    status=delete; reason="squash-merged"
  elif is_merged_pr "$br" "$sha"; then
    status=delete; reason="pr-merged"
  elif [ "$track" = "[gone]" ]; then
    status=review; reason="upstream-gone"
  fi

  [ "$status" = keep ] && continue
  # 保護ブランチとベースブランチは対象外 (出力もしない)
  [ "$br" = "$default" ] && continue
  case "$protected" in *" $br "*) continue ;; esac
  if [ -n "$wt" ]; then
    status=skip; reason="$reason, checked-out: $wt"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$status" "$br" "$reason" "${sha:0:9}" "$date" "$subj"
done

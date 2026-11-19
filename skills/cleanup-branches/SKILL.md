---
name: cleanup-branches
description: マージ済みのローカルブランチを検出して削除するスキル。通常マージに加えて squash / rebase マージ済みのブランチも判定し、一覧を見せて確認してから削除する。リモートブランチは消さない。ユーザーが「マージ済みブランチを消して」「ブランチを掃除して」「ローカルブランチを整理して」など不要ブランチを片付ける意図を示したら必ず使用する。
argument-hint: "[ベースブランチ] [--dry-run] [-y]"
allowed-tools: Bash, Read, AskUserQuestion
---

マージ済みのローカルブランチを削除する。削除するのはローカルブランチだけで、リモートブランチ・worktree・stash には触れない。

## 手順

1. プロジェクト (git root) の `.agents/skills-config/cleanup-branches/config.json` があれば読む (無くてよい)

   ```json
   { "base": "develop", "protected": ["staging", "release"] }
   ```

2. 分類スクリプトを実行する。第 1 引数はベースブランチ (`$ARGUMENTS` > config の `base` > 無ければ `-` で自動判定)、以降は config の `protected`

   ```bash
   bash <このスキルのディレクトリ>/scripts/list-merged.sh <base|-> [protected...]
   ```

   `git fetch --prune` の後、ブランチごとに 1 行の TSV (`status / branch / reason / sha / 日付 / 件名`) を返す。未マージのブランチ・ベースブランチ・保護ブランチ (`main` `master` `develop` + `protected`) は出力されない。

   | status | reason | 意味 | 扱い |
   |---|---|---|---|
   | `delete` | `merged` | ベースに取り込み済み (通常マージ) | 削除対象 |
   | `delete` | `squash-merged` | 同じ差分がベースにある (squash / rebase マージ) | 削除対象 |
   | `delete` | `pr-merged` | マージ済み PR の head とローカルの先端が一致 (`gh` が使える場合) | 削除対象 |
   | `review` | `upstream-gone` | リモートブランチは消えているが、マージは確認できない | 既定では残す |
   | `skip` | `…, checked-out: <path>` | マージ済みだが現在のブランチ、または worktree で使用中 | 削除しない |

3. 結果を status ごとの表でユーザーに見せる。`delete` も `review` も 0 件ならその旨を報告して終了。`--dry-run` ならここで終了
4. AskUserQuestion で削除範囲を確認する (`-y` 指定時は質問せず `delete` のみ削除)。選択肢は「`delete` の N 件を削除」「`review` も含めて削除」(`review` がある場合のみ)「やめる」。一部だけ残したい場合は自由記述で受ける
   - `review` は未マージのコミットを失う可能性があるため、含める場合は対象ブランチ名を選択肢の説明に列挙する
   - 現在のブランチが `skip` に入っている場合は、ベースブランチに切り替えてから削除するかを併せて聞く。未コミットの変更があれば切り替えず残す
5. 確認されたブランチを削除する。判定はスクリプトで済んでいるので `-D` を使う (squash マージ済みは `-d` だと拒否される)

   ```bash
   git branch -D <branch>...
   ```

## 完了報告

削除したブランチを `ブランチ名 (sha)` の形で列挙し、残したブランチ (`review` / `skip`) とその理由を添える。sha があれば `git branch <ブランチ名> <sha>` で復元できることを 1 行で伝える。

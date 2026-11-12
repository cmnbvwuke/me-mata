#!/usr/bin/env bash
# Atualiza folha/main sobre o branch de release do upstream e regrava a série de patches.
#
# Fluxo:
#   1. git fetch upstream <branch>
#   2. git rebase upstream/<branch> (resolva conflitos manualmente se aparecerem)
#   3. exporta os commits do fork de volta para folha/patches/ (git format-patch)
#
# Uso: folha/scripts/sync-upstream.sh [novo-branch-upstream]
#   Sem argumento: usa UPSTREAM_BRANCH de folha.conf.
#   Com argumento (ex.: libreoffice-26-2): muda de release e atualiza folha.conf.
set -euo pipefail

FOLHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$FOLHA_DIR/folha.conf"
FOLHA_SRC="${FOLHA_SRC:-$FOLHA_DIR/core}"
OLD_BRANCH="$UPSTREAM_BRANCH"
NEW_BRANCH="${1:-$UPSTREAM_BRANCH}"

cd "$FOLHA_SRC"
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "árvore suja em $FOLHA_SRC" >&2; exit 1; }

git fetch upstream "$NEW_BRANCH:refs/remotes/upstream/$NEW_BRANCH"
git checkout folha/main

# Base antiga = merge-base com o branch antigo; reaplica só os commits do fork.
OLD_BASE="$(git merge-base folha/main "upstream/$OLD_BRANCH")"
git rebase --onto "upstream/$NEW_BRANCH" "$OLD_BASE" folha/main

"$FOLHA_DIR/scripts/export-patches.sh"

if [ "$NEW_BRANCH" != "$OLD_BRANCH" ]; then
    sed -i "s/^UPSTREAM_BRANCH=.*/UPSTREAM_BRANCH=$NEW_BRANCH/" "$FOLHA_DIR/folha.conf"
    echo ">> folha.conf agora aponta para $NEW_BRANCH"
fi
echo ">> sincronizado. Revise 'git -C $FOLHA_DIR diff' e faça commit dos patches."

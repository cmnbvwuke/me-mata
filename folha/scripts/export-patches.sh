#!/usr/bin/env bash
# Exporta os commits de folha/main (acima do upstream) para folha/patches/.
# Rode depois de fazer commits na árvore core/ para que eles entrem no repositório.
set -euo pipefail

FOLHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$FOLHA_DIR/folha.conf"
FOLHA_SRC="${FOLHA_SRC:-$FOLHA_DIR/core}"

cd "$FOLHA_SRC"
BASE="$(git merge-base folha/main "upstream/$UPSTREAM_BRANCH")"

rm -f "$FOLHA_DIR"/patches/*.patch
git format-patch --quiet --zero-commit --no-signature --no-numbered \
    -o "$FOLHA_DIR/patches" "$BASE..folha/main"
echo ">> $(ls "$FOLHA_DIR"/patches/*.patch 2>/dev/null | wc -l) patch(es) em folha/patches/"

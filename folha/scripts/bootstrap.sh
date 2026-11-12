#!/usr/bin/env bash
# Prepara a árvore de código do Folha:
#   1. clona o core do LibreOffice (branch de release estável) em $FOLHA_SRC
#   2. cria o branch folha/main
#   3. aplica a série de patches de folha/patches/ (git am)
#   4. instala o autogen.input escolhido (dev | ci | release)
#
# Uso: folha/scripts/bootstrap.sh [dev|ci|release]
# Variáveis: FOLHA_SRC (padrão: <repo>/folha/core), FOLHA_UPSTREAM_BRANCH,
#            FOLHA_UPSTREAM_URL, FOLHA_DEPTH (0 = histórico completo)
set -euo pipefail

PROFILE="${1:-dev}"
FOLHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../folha.conf
source "$FOLHA_DIR/folha.conf"

FOLHA_SRC="${FOLHA_SRC:-$FOLHA_DIR/core}"
FOLHA_UPSTREAM_URL="${FOLHA_UPSTREAM_URL:-$UPSTREAM_URL}"
FOLHA_UPSTREAM_BRANCH="${FOLHA_UPSTREAM_BRANCH:-$UPSTREAM_BRANCH}"
FOLHA_DEPTH="${FOLHA_DEPTH:-1}"

INPUT="$FOLHA_DIR/autogen/$PROFILE.input"
[ -f "$INPUT" ] || { echo "perfil desconhecido: $PROFILE (use dev, ci ou release)" >&2; exit 1; }

if [ ! -d "$FOLHA_SRC/.git" ]; then
    depth_args=()
    [ "$FOLHA_DEPTH" != "0" ] && depth_args=(--depth "$FOLHA_DEPTH")
    echo ">> clonando $FOLHA_UPSTREAM_URL ($FOLHA_UPSTREAM_BRANCH) em $FOLHA_SRC"
    git clone "${depth_args[@]}" --origin upstream --branch "$FOLHA_UPSTREAM_BRANCH" \
        "$FOLHA_UPSTREAM_URL" "$FOLHA_SRC"
fi

cd "$FOLHA_SRC"
git config user.name  >/dev/null || git config user.name  "Folha Build"
git config user.email >/dev/null || git config user.email "build@folha.invalid"

if ! git rev-parse --verify -q folha/main >/dev/null; then
    git checkout -b folha/main "upstream/$FOLHA_UPSTREAM_BRANCH" 2>/dev/null \
        || git checkout -b folha/main
    shopt -s nullglob
    patches=("$FOLHA_DIR"/patches/*.patch)
    if [ ${#patches[@]} -gt 0 ]; then
        echo ">> aplicando ${#patches[@]} patch(es)"
        git am --3way "${patches[@]}"
    fi
else
    git checkout folha/main
fi

cp "$INPUT" autogen.input
if [ "$PROFILE" = "release" ] && [ -d "$FOLHA_SRC/branding/folha" ]; then
    echo "--with-branding=$FOLHA_SRC/branding/folha" >> autogen.input
fi

echo ">> pronto. Próximo passo: cd $FOLHA_SRC && ./autogen.sh && make"

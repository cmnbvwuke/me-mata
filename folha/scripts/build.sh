#!/usr/bin/env bash
# Build reprodutível dentro do container (folha/docker/Dockerfile).
#
# Uso: folha/scripts/build.sh [dev|ci|release] [alvo-make...]
#   Ex.: folha/scripts/build.sh dev            # build completo
#        folha/scripts/build.sh dev sw         # só o módulo Writer
#
# O código fica em folha/core (montado no container) e o cache do ccache
# em ~/.cache/folha-ccache, para builds incrementais entre execuções.
set -euo pipefail

PROFILE="${1:-dev}"; shift || true
FOLHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$FOLHA_DIR/.." && pwd)"
IMAGE="${FOLHA_IMAGE:-folha-build:24.04}"
CCACHE_HOST="${FOLHA_CCACHE_DIR:-$HOME/.cache/folha-ccache}"
mkdir -p "$CCACHE_HOST"

docker build -t "$IMAGE" -f "$FOLHA_DIR/docker/Dockerfile" "$FOLHA_DIR"

docker run --rm $( [ -t 0 ] && echo -it ) \
    -u "$(id -u):$(id -g)" \
    -v "$REPO_DIR:/work" \
    -v "$CCACHE_HOST:/ccache" \
    -e CCACHE_DIR=/ccache -e CCACHE_MAXSIZE=30G \
    -w /work \
    "$IMAGE" \
    bash -c "folha/scripts/bootstrap.sh $PROFILE && cd folha/core && ./autogen.sh && make $*"

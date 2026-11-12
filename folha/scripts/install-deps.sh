#!/usr/bin/env bash
# Instala as dependências de build do Folha (LibreOffice) no Ubuntu 24.04.
# Usado pelo Dockerfile e pelo CI. Precisa rodar como root (ou via sudo).
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Habilita os repositórios de código-fonte (deb-src), exigidos por "apt-get build-dep".
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
fi

apt-get update
apt-get build-dep -y libreoffice
apt-get install -y --no-install-recommends \
    git ccache ca-certificates curl uuid-runtime meson \
    autoconf automake bison flex gperf nasm zip unzip \
    qt6-base-dev qt6-base-private-dev qt6-multimedia-dev \
    libgtk-3-dev libgtk-4-dev \
    python3 python3-dev poppler-utils

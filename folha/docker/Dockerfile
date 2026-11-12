# Ambiente de build do Folha (fork do LibreOffice) para Linux.
# Uso: folha/scripts/build.sh  (ou: docker build -t folha-build:24.04 -f folha/docker/Dockerfile folha)
FROM ubuntu:24.04

COPY scripts/install-deps.sh /tmp/install-deps.sh
RUN /tmp/install-deps.sh && rm -rf /var/lib/apt/lists/* /tmp/install-deps.sh

# O build do LibreOffice se recusa a rodar como root; o build.sh passa -u <uid>.
ENV HOME=/tmp \
    CCACHE_DIR=/ccache \
    LANG=C.UTF-8

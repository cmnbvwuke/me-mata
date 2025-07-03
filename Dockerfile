FROM ubuntu:22.04

# Instalar dependências básicas
RUN apt-get update && apt-get install -y curl apt-transport-https gnupg ca-certificates software-properties-common

# Instalar Emby Server
RUN curl -fsSL https://mediabrowser.github.io/embytools/emby-server-deb.pub | apt-key add -
RUN echo "deb [arch=amd64] https://repo.emby.media/ubuntu jammy main" > /etc/apt/sources.list.d/emby-server.list
RUN apt-get update && apt-get install -y emby-server

# Instalar rclone
RUN curl https://rclone.org/install.sh | bash

# Criar pasta para os vídeos copiados do MEGA
RUN mkdir -p /data/mega_videos

# Porta padrão do Emby
EXPOSE 8096

# Comando de entrada (Emby inicia, e rclone pode ser executado via Shell)
CMD ["emby-server"]

FROM ubuntu:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    git \
    zsh \
    rsync \
    sudo \
    build-essential \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash linuxbrew \
  && echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER linuxbrew
WORKDIR "/home/linuxbrew"
COPY --chown=linuxbrew:linuxbrew . "/home/linuxbrew"

CMD ["zsh"]
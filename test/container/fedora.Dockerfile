FROM fedora:latest

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN dnf install -y \
    curl \
    file \
    git \
    sudo \
    gcc \
    gcc-c++ \
    make \
    zsh \
    rsync \
  && dnf clean all

RUN useradd -m -s /bin/bash linuxbrew \
  && echo "linuxbrew ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER linuxbrew
WORKDIR "/home/linuxbrew"
COPY --chown=linuxbrew:linuxbrew . "/home/linuxbrew"

CMD ["zsh"]
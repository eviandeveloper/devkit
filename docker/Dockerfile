# devkit/docker/Dockerfile

FROM fedora:44

# ============================================================================
# Variables de entorno
# ============================================================================

ENV CCACHE_DIR=/home/dev/.cache/ccache
ENV CCACHE_MAXSIZE=10G

ENV CONAN_HOME=/home/dev/.conan2

# ============================================================================
# Instalación del entorno de desarrollo
# ============================================================================

RUN dnf -y install \
    clang \
    clang-tools-extra \
    gcc \
    gcc-c++ \
    libasan \
    libubsan \
    libtsan \
    cmake \
    ninja-build \
    ccache \
    pkgconf-pkg-config \
    python3 \
    python3-pip \
    git \
    sudo \
    findutils \
    procps-ng \
    make \
    dpkg \
    dpkg-dev \
    rpm-build \
    tar \
    gzip \
    bzip2 \
    xz \
    unzip \
    zip \
    which \
    file \
    diffutils \
    patch \
    graphviz \
    gdb \
    lldb \
    strace \
    ltrace \
    entr \
    perf \
    valgrind \
    doxygen \
    cppcheck \
    include-what-you-use \
    && dnf clean all

# ============================================================================
# Conan
# ============================================================================

COPY docker/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

RUN pre-commit install

# ============================================================================
# Usuario de desarrollo
# ============================================================================

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd \
        --gid ${USER_GID} \
        ${USERNAME} \
    && useradd \
        --uid ${USER_UID} \
        --gid ${USER_GID} \
        --create-home \
        --shell /bin/bash \
        ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}

WORKDIR /home/dev/project

# ============================================================================
# Conan
# ============================================================================

RUN conan profile detect --force

# Copiamos los perfiles custom del proyecto para que estén disponibles
# dentro del contenedor sin depender del volumen montado en tiempo de build
COPY --chown=${USERNAME}:${USERNAME} conan/profiles/ /home/dev/.conan2/profiles/
COPY --chown=${USERNAME}:${USERNAME} conan/settings_user.yml /home/dev/.conan2/settings_user.yml

# ============================================================================
# ccache
# ============================================================================

RUN mkdir -p "${CCACHE_DIR}"

# ============================================================================
# Shell por defecto
# ============================================================================

CMD ["/bin/bash"]

# syntax=docker/dockerfile:1
# hadolint ignore=DL3006, DL3008, SC2181
#
# Multi-stage layout:
# - py-builder: compile/install Python deps into /opt/addon-venv (same libc as final via BUILD_FROM).
# - assets: downloads + VSIX extraction on a slim Debian stage (no Supervisor base required).
# - final: hassio-addons/debian-base + apt runtime + copies from prior stages.
#
ARG BUILD_FROM=ghcr.io/hassio-addons/debian-base:9.1.0

# -----------------------------------------------------------------------------
# Python CLI stack (ESPHome, yamllint, huggingface_hub) in a dedicated venv.
# Keeps python3-dev and wheel build tooling out of the runtime image.
# -----------------------------------------------------------------------------
FROM ${BUILD_FROM} AS py-builder

COPY requirements.txt /tmp/requirements.txt

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential \
        python3 \
        python3-dev \
        python3-venv \
    ; \
    python3 -m venv /opt/addon-venv; \
    /opt/addon-venv/bin/pip install --upgrade pip setuptools wheel; \
    /opt/addon-venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt; \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Binary artifacts: code-server, Node+globals, Bun, HA CLI, marketplace VSIX.
# Isolated from rootfs/ changes so dependency/version bumps cache independently.
# -----------------------------------------------------------------------------
FROM debian:trixie-slim AS assets

ARG BUILD_ARCH=amd64
ARG CODE_SERVER_VERSION="v4.107.0"
ARG HA_CLI_VERSION="4.45.0"
ARG NODE_VERSION="22.14.0"
ARG OPENCLAUDE_NPM_VERSION="0.1.7"
ARG FALLOW_NPM_VERSION="2.13.0"
ARG PI_CODING_AGENT_NPM_VERSION="0.65.0"
ARG BUN_VERSION="1.2.6"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY vscode.extensions /tmp/vscode.extensions

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/root/.npm,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        libarchive-tools \
        unzip \
        uuid-runtime \
        xz-utils \
    ; \
    ARCH=""; NODE_ARCH=""; BUN_ZIP_ARCH=""; BUN_DIR=""; \
    case "${BUILD_ARCH}" in \
        aarch64) ARCH="arm64"; NODE_ARCH="arm64"; BUN_ZIP_ARCH="aarch64"; BUN_DIR="bun-linux-aarch64" ;; \
        amd64) ARCH="amd64"; NODE_ARCH="x64"; BUN_ZIP_ARCH="x64"; BUN_DIR="bun-linux-x64" ;; \
        *) echo "unsupported BUILD_ARCH=${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /artifacts/code-server /artifacts/node /artifacts/extensions; \
    curl -fsSL -o /tmp/code.tar.gz \
        "https://github.com/coder/code-server/releases/download/${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION#v}-linux-${ARCH}.tar.gz"; \
    tar zxf /tmp/code.tar.gz --strip-components=1 -C /artifacts/code-server; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
        | tar -xJ -C /artifacts/node --strip-components=1; \
    export PATH="/artifacts/node/bin:${PATH}"; \
    npm install -g \
        "pnpm@9.15.4" \
        "@gitlawb/openclaude@${OPENCLAUDE_NPM_VERSION}" \
        "fallow@${FALLOW_NPM_VERSION}" \
        "@mariozechner/pi-coding-agent@${PI_CODING_AGENT_NPM_VERSION}"; \
    command -v openclaude; \
    command -v fallow && fallow --version; \
    command -v pi; \
    curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${BUN_ZIP_ARCH}.zip" -o /tmp/bun.zip; \
    unzip -q /tmp/bun.zip -d /tmp/bun-extract; \
    mv "/tmp/bun-extract/${BUN_DIR}/bun" /artifacts/bun; \
    chmod +x /artifacts/bun; \
    curl -fsSL -o /artifacts/ha \
        "https://github.com/home-assistant/cli/releases/download/${HA_CLI_VERSION}/ha_${BUILD_ARCH}"; \
    chmod +x /artifacts/ha; \
    uuid="$(uuidgen)"; \
    while read -r ext; do \
        [[ -z "${ext}" || "${ext}" =~ ^# ]] && continue; \
        extention="${ext%%#*}"; \
        vendor="${extention%%.*}"; \
        slug="${extention#*.}"; \
        version="${ext##*#}"; \
        echo "Installing vscode extension: ${slug} by ${vendor} @ ${version}"; \
        curl -JL --retry 5 -o "/tmp/${extention}-${version}.vsix" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36" \
            -H "x-market-user-id: ${uuid}" \
            "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${vendor}/vsextensions/${slug}/${version}/vspackage"; \
        mkdir -p "/artifacts/extensions/${extention}-${version}"; \
        bsdtar --strip-components=1 -xf "/tmp/${extention}-${version}.vsix" \
            -C "/artifacts/extensions/${extention}-${version}" extension; \
        sleep 1; \
    done < /tmp/vscode.extensions; \
    ls -la /artifacts/extensions/; \
    rm -rf /tmp/* /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Runtime
# -----------------------------------------------------------------------------
FROM ${BUILD_FROM}

ENV \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    DOTNET_ROOT=/usr/share/dotnet \
    PATH="/opt/addon-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=py-builder /opt/addon-venv /opt/addon-venv

COPY --from=assets /artifacts/code-server /usr/local/lib/code-server
COPY --from=assets /artifacts/node/ /usr/local/
COPY --from=assets /artifacts/bun /usr/local/bin/bun
COPY --from=assets /artifacts/ha /usr/bin/ha
COPY --from=assets /artifacts/extensions/ /usr/local/lib/code-server/lib/vscode/extensions/

ARG BUILD_ARCH=amd64
ARG DOTNET_CHANNEL="8.0"
ARG UV_VERSION="0.6.14"
ARG FALLOW_SKILLS_REF="v1.0.0"
# .NET SDK: install via dotnet-install.sh. The packages.microsoft.com apt repo fails on Debian
# Trixie because apt/sqv rejects the Microsoft signing key (SHA1 policy from 2026-02-01).

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ack \
        colordiff \
        git \
        iputils-ping \
        locales \
        mariadb-client \
        mosquitto-clients \
        net-tools \
        nmap \
        openssh-client \
        openssl \
        python3-venv \
        python3 \
        unzip \
        wget \
        zip \
        zsh \
        less \
    ; \
    apt-get install -y --no-install-recommends \
        bat \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        curl \
        direnv \
        fd-find \
        fzf \
        gh \
        git-lfs \
        jq \
        just \
        pipx \
        pkg-config \
        ripgrep \
        rsync \
        tig \
        xz-utils \
        yarnpkg \
    ; \
    curl -fsSL -o /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh; \
    chmod +x /tmp/dotnet-install.sh; \
    /tmp/dotnet-install.sh --channel "${DOTNET_CHANNEL}" --install-dir /usr/share/dotnet; \
    ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet; \
    dotnet --info; \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen; \
    locale-gen; \
    ln -sf /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server; \
    git clone --branch master --single-branch --depth 1 \
        "https://github.com/robbyrussell/oh-my-zsh.git" /root/.oh-my-zsh; \
    git clone --branch master --single-branch --depth 1 \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
    git clone --branch master --single-branch --depth 1 \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        /root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting; \
    sed -i -e "s#bin/bash#bin/zsh#" /etc/passwd; \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 10; \
    git lfs install; \
    rm -rf /usr/local/share/fallow-skills; \
    git clone --depth 1 --branch "${FALLOW_SKILLS_REF}" \
        https://github.com/fallow-rs/fallow-skills.git /usr/local/share/fallow-skills; \
    UV_ARCH=""; \
    case "${BUILD_ARCH}" in \
        aarch64) UV_ARCH="aarch64" ;; \
        amd64) UV_ARCH="x86_64" ;; \
        *) echo "unsupported BUILD_ARCH=${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tgz \
        "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${UV_ARCH}-unknown-linux-gnu.tar.gz"; \
    tar -xzf /tmp/uv.tgz -C /tmp; \
    install -m 0755 "/tmp/uv-${UV_ARCH}-unknown-linux-gnu/uv" /usr/local/bin/uv; \
    install -m 0755 "/tmp/uv-${UV_ARCH}-unknown-linux-gnu/uvx" /usr/local/bin/uvx; \
    uv --version; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    ln -sf /usr/bin/batcat /usr/local/bin/bat; \
    ln -sf /usr/bin/yarnpkg /usr/local/bin/yarn; \
    node --version; \
    npm --version; \
    bun --version; \
    find /usr/local /opt/addon-venv \
        \( \( -type d -a \( -name test -o -name tests -o -name '__pycache__' \) \) \
        -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \) \
        -exec rm -rf '{}' +; \
    rm -fr /root/.cache /tmp/*; \
    find /var/cache -mindepth 1 -maxdepth 1 ! -name apt -exec rm -rf {} +; \
    find /var/cache/apt -mindepth 1 -delete 2>/dev/null || true; \
    rm -fr /var/log/*; \
    rm -rf /var/lib/apt/lists/*

COPY vscode.extensions /root/vscode.extensions

COPY rootfs /

HEALTHCHECK \
    CMD curl --fail http://127.0.0.1:1337/healthz || exit 1

ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="local" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="local" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}

# See https://github.com/rust-lang/docker-rust/blob/master/1.67.1/bookworm/Dockerfile
FROM nvcr.io/nvidia/cuda:12.0.1-base-ubuntu22.04 AS rust-base
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo/ \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.67.1
RUN set -e -x; \
    apt-get update; \
    apt-get -y --no-install-recommends install  wget; \
    apt-get clean; \
    apt-get autoclean; \
    rm -rf /var/cache/apt/*; \
    rm -rf /var/lib/apt/lists/*
RUN wget https://static.rust-lang.org/rustup/archive/1.25.2/x86_64-unknown-linux-gnu/rustup-init \
    && ( echo "bb31eaf643926b2ee9f4d8d6fc0e2835e03c0a60f34d324048aa194f0b29a71c *rustup-init" | sha256sum -c ) \
    && chmod +x rustup-init \
    && ./rustup-init \
        -y \
        --no-modify-path \
        --profile minimal \
        --default-toolchain $RUST_VERSION \
        --default-host x86_64-unknown-linux-gnu \
    && rm rustup-init \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME \
    && rustup --version \
    && cargo --version \
    && rustc --version

FROM rust-base
WORKDIR /work
# install build dependencies:
RUN set -e -x; \
    echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get -y --no-install-recommends install \
        bison \
        build-essential \
        ca-certificates \
        clang \
        clang-format \
        clang-tidy \
        cmake \
        cppcheck \
        curl \
        dpkg-dev \
        file \
        flex \
        g++ \
        gcc \
        gi-docgen \
        git \
        iwyu \
        lcov \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libexpat1-dev \
        libgl-dev \
        libglfw3-dev \
        libglib2.0-0 \
        libglib2.0-dev \
        libglx-dev \
        libopengl-dev \
        libpango1.0-dev \
        libssl-dev \
        libx11-xcb-dev \
        libgtk-4-dev \
        libgdk-pixbuf2.0-dev \
        libxml2-dev \
        make \
        nasm \
        pkg-config \
        python-is-python3 \
        python3-pip \
        python3-venv \
        python3-yaml \
        util-linux \
        valgrind; \
    apt-get clean;\
    apt-get autoclean; \
    rm -rf /var/cache/apt/*; \
    rm -rf /var/lib/apt/lists/*; \
    python -m venv /work/.venv; \
    . /work/.venv/bin/activate; \
    pip install --no-cache-dir \
        meson==0.64.0 \
        ninja==1.11.1 \
        PyYAML==6.0.0 \
        tomli==2.0.1; \
    cargo install cargo-c; \
    cargo install cargo-cache; \
    cargo-cache --remove-dir all

# build gstreamer w/ Rust plugins
ARG GSTREAMER_COMMIT_HASH=f6b2b716b2b15a043eb392cd664150a83179f841
WORKDIR /work/gstreamer/
RUN set -e -x; \
    . /work/.venv/bin/activate; \
    git init; \
    git config user.name root; \
    git config user.email root@buildkitsandbox.local; \
    git remote add origin https://gitlab.freedesktop.org/gstreamer/gstreamer.git; \
    git fetch origin "${GSTREAMER_COMMIT_HASH}" --depth 1; \
    git checkout FETCH_HEAD; \
    git remote add origin-ystreet https://gitlab.freedesktop.org/ystreet/gstreamer.git; \
    git fetch origin-ystreet baseparse-keep-upstream-pts; \
    git cherry-pick 8d4b5d7fe37fe63a10f8090efa5de9e4a11e354f; \
    meson build --prefix=/usr -Dbuildtype=debugoptimized \
        -Dbad=enabled \
        -Dbase=enabled \
        -Ddevtools=disabled \
        -Ddoc=disabled \
        -Dexamples=disabled \
        -Dges=disabled \
        -Dgood=enabled \
        -Dgst-examples=disabled \
        -Dintrospection=disabled \
        -Dlibav=disabled \
        -Dpython=disabled \
        -Dqt5=disabled \
        -Drs=enabled \
        -Drs:csound=disabled \
        -Drs:gtk4=disabled \
        -Drs:sodium=disabled \
        -Drtsp_server=enabled \
        -Dtests=disabled \
        -Dtls=enabled \
        -Dtools=enabled \
        -Dugly=enabled; \
    ninja -C build; \
    ninja install -C build; \
    cd /work; \
    rm -rf /work/gstreamer; \
    cargo-cache --remove-dir all

WORKDIR /work

# setup su for dep installation
RUN sed -i '/pam_rootok.so$/aauth sufficient pam_permit.so' /etc/pam.d/su

ADD entrypoint /usr/local/bin/entrypoint
CMD ["/usr/local/bin/entrypoint"]

ARG BASE=debian:sid
FROM ${BASE}

# install debian packages:
ENV DEBIAN_FRONTEND=noninteractive
RUN set -e -x; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        # infra
        ca-certificates python3-yaml \
        # build
        cmake pkg-config make gcc g++ \
        # coverage report
        curl lcov \
        # clang
        clang clang-tidy clang-format \
        # C/C++ linters \
        cppcheck iwyu \
        # used by clang-format
        git \
        # cpack
        file dpkg-dev \
        # base system (su)
        util-linux

# ctest -D ExperimentalMemCheck; may not work in all architectures
RUN apt-get install -y --no-install-recommends valgrind || true

# setup su for dep installation
RUN sed -i '/pam_rootok.so$/aauth sufficient pam_permit.so' /etc/pam.d/su

ADD entrypoint /usr/local/bin/entrypoint
CMD ["/usr/local/bin/entrypoint"]

# install build dependencies for gstreamer:
RUN set -e -x; \
    echo 'Acquire::Retries "3";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bison \
        build-essential \
        flex \
        gi-docgen \
        git \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libexpat1-dev \
        libglib2.0-dev \
        libpango1.0-dev \
        libxml2-dev \
        make \
        meson \
        nasm \
        ninja-build \
        pkg-config

# specify the commit of gstreamer to build:
ARG GSTREAMER_COMMIT_HASH=d75a69ec951949962ee5a3df3f136452e8712a88

# build and install gstreamer from gitlab upstream:
RUN set -e -x; \
    mkdir -p /work/gstreamer; \
    cd /work/gstreamer; \
    git init; \
    git remote add origin https://gitlab.freedesktop.org/gstreamer/gstreamer.git; \
    git fetch origin $GSTREAMER_COMMIT_HASH; \
    git reset --hard FETCH_HEAD; \
    meson setup --prefix=/usr -Dbuildtype=release \
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
        -Drtsp_server=enabled \
        -Dtests=disabled \
        -Dtls=enabled \
        -Dtools=enabled \
        -Dugly=enabled \
        -Dgst-plugins-base:gl=disabled \
        -Dgst-plugins-bad:gl=disabled \
        /work/gstreamer/build \
        /work/gstreamer/; \
    ninja -C build; \
    ninja install -C build; \
    cd $HOME; \
    rm -rf /work/

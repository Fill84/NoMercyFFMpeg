FROM ubuntu:latest AS base

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0"
LABEL description="Cross-compile FFmpeg for Windows, Linux and Aarch64"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

ENV ffmpeg_version=7.1 \
    iconv_version=1.18 \
    libxml2_version=2.13 \
    zlib_version=1.3.1 \
    fftw3_version=3.3.10 \
    freetype_version=2.13.3 \
    fribidi_version=1.0.16 \
    openssl_version=3.4.0 \
    fontconfig_version=2.15.0 \
    harfbuzz_version=10.1.0 \
    libudfread_version=1.1.2 \
    avisynth_version=3.7.3 \
    chromaprint_version=1.5.1 \
    libass_version=0.17.3 \
    libdbplus_version=0.2.0 \
    libbluray_version=1.3.4 \
    twolame_version=0.4.0 \
    mp3lame_version=3.100 \
    fdk_aac_version=2.0.3 \
    opus_version=1.5.2 \
    libvpx_version=1.15.0 \
    x264_version=stable \
    x265_version=master \
    xvid_version=1.3.7 \
    libwebp_version=1.4.0 \
    openjpeg_version=2.5.3 \
    zimg_version=3.0.5 \
    nvcodec_version=12.2.72.0

# Dependencies for building ffmpeg
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    autoconf \
    automake \
    autopoint \
    autotools-dev \
    bison \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    doxygen \
    fig2dev \
    flex \
    gettext \
    git \
    gperf \
    groff \
    libaacs-dev \
    libc6 \
    libc6-dev \
    libtool \
    meson \
    nasm \
    libssl-dev \
    pkg-config \
    python3 \
    python3-dev \
    python3-venv \
    subversion \
    wget \
    yasm \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN git config --global user.email "builder@nomercy.tv" \
    && git config --global user.name "Builder" \
    && git config --global advice.detachedHead false

# Install rust and cargo-c
ENV CARGO_HOME="/opt/cargo" RUSTUP_HOME="/opt/rustup" PATH="/opt/cargo/bin:${PATH}"
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --no-modify-path && \
    cargo install cargo-c && rm -rf "${CARGO_HOME}"/registry "${CARGO_HOME}"/git

WORKDIR /build

# Download iconv
RUN wget -O libiconv.tar.gz http://ftp.gnu.org/gnu/libiconv/libiconv-${iconv_version}.tar.gz && \
    tar -xvf libiconv.tar.gz && rm libiconv.tar.gz && mv libiconv-* iconv

# Download libxml2
RUN git clone --branch ${libxml2_version} https://github.com/GNOME/libxml2.git libxml2

# Download zlib
RUN git clone --branch v${zlib_version} https://github.com/madler/zlib.git zlib

# Download fftw3 
RUN wget -O fftw3.tar.gz http://www.fftw.org/fftw-${fftw3_version}.tar.gz && \
    tar -xvf fftw3.tar.gz && rm fftw3.tar.gz && mv fftw-${fftw3_version} fftw3

# Download freetype
RUN wget -O freetype.tar.gz https://download.savannah.gnu.org/releases/freetype/freetype-${freetype_version}.tar.gz \
    && tar -xzf freetype.tar.gz && rm freetype.tar.gz && mv freetype-${freetype_version} freetype

# Download fribidi
RUN wget https://github.com/fribidi/fribidi/releases/download/v${fribidi_version}/fribidi-${fribidi_version}.tar.xz \
    && tar -xJf fribidi-${fribidi_version}.tar.xz && rm fribidi-${fribidi_version}.tar.xz && mv fribidi-${fribidi_version} fribidi

# Download openssl
RUN git clone --branch openssl-${openssl_version} https://github.com/openssl/openssl.git openssl \
    && cd openssl && git submodule update --init --recursive --depth=1 && cd ..

# Download fontconfig
RUN git clone --branch ${fontconfig_version} https://gitlab.freedesktop.org/fontconfig/fontconfig.git fontconfig

# Download harfbuzz
RUN git clone --branch ${harfbuzz_version} https://github.com/harfbuzz/harfbuzz.git harfbuzz

# Download libudfread
RUN git clone --branch ${libudfread_version} https://code.videolan.org/videolan/libudfread libudfread

# Download avisynth
RUN git clone --branch v${avisynth_version} https://github.com/AviSynth/AviSynthPlus.git avisynth

# Download chromaprint
RUN git clone --branch v${chromaprint_version} https://github.com/acoustid/chromaprint.git chromaprint

# Download libass
RUN git clone --branch ${libass_version} https://github.com/libass/libass.git libass

# Download libdbplus
RUN git clone --branch ${libdbplus_version} https://code.videolan.org/videolan/libdbplus libdbplus

# Download libbluray
RUN git clone --branch ${libbluray_version} https://code.videolan.org/videolan/libbluray.git libbluray

# Download twolame
RUN git clone --branch ${twolame_version} https://github.com/njh/twolame.git twolame

# Download mp3lame
RUN wget -O mp3lame.tar.gz https://downloads.sourceforge.net/project/lame/lame/${mp3lame_version}/lame-${mp3lame_version}.tar.gz \
    && tar -xzf mp3lame.tar.gz && rm mp3lame.tar.gz && mv lame-${mp3lame_version} lame

# Download fdk-aac
RUN wget -O fdk-aac.tar.gz https://github.com/mstorsjo/fdk-aac/archive/v${fdk_aac_version}.tar.gz \
    && tar -xzf fdk-aac.tar.gz && rm fdk-aac.tar.gz && mv fdk-aac-* fdk-aac

# Download Opus
RUN git clone --branch v${opus_version} https://github.com/xiph/opus.git opus

# Download libvpx
RUN git clone --branch v${libvpx_version} https://chromium.googlesource.com/webm/libvpx.git libvpx

# Download x264
RUN git clone --branch ${x264_version} https://code.videolan.org/videolan/x264.git x264

# Download x265
RUN wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/${x265_version}.tar.bz2 \
    && tar xjf x265.tar.bz2 && rm x265.tar.bz2 && mv multicoreware-x265_git-* x265

# Download xvidcore
RUN wget -O xvidcore.tar.gz https://downloads.xvid.com/downloads/xvidcore-${xvid_version}.tar.gz \
    && tar -xzf xvidcore.tar.gz && rm xvidcore.tar.gz

# Download libwebp
RUN wget -O libwebp.tar.gz https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${libwebp_version}.tar.gz \
    && tar -xzf libwebp.tar.gz && rm libwebp.tar.gz && mv libwebp-${libwebp_version} libwebp

# Download openjpeg
RUN git clone --branch v${openjpeg_version} https://github.com/uclouvain/openjpeg.git openjpeg

# Download zimg
RUN git clone --branch release-${zimg_version} https://github.com/sekrit-twc/zimg.git zimg

# Download ffnvcodec
RUN git clone --branch n${nvcodec_version} https://github.com/FFmpeg/nv-codec-headers.git ffnvcodec

# Download ffmpeg
RUN wget -O ffmpeg.tar.bz2 https://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2 \
    && tar -xjf ffmpeg.tar.bz2 && rm ffmpeg.tar.bz2 && mv ffmpeg-${ffmpeg_version} ffmpeg

ADD ./start.sh /start.sh
ADD ./export.sh /export.sh
RUN chmod 755 /start.sh /export.sh

# Set the entrypoint
CMD ["/start.sh"]
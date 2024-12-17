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
    zlib_version=1.3.1 \
    libxml2_version=2.13 \
    freetype_version=2.13.3 \
    fribidi_version=1.0.16 \
    harfbuzz_version=10.1.0 \
    libass_version=0.17.3 \
    mp3lame_version=3.100 \
    libvpx_version=1.15.0 \
    x264_version=stable \
    x265_version=master \
    xvid_version=1.3.7 \
    fdk_aac_version=2.0.3 \
    opus_version=1.5.2 \
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
    libc6 \
    libc6-dev \
    libtool \
    # m4 \
    meson \
    nasm \
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

WORKDIR /build

# Download iconv
RUN wget -O libiconv.tar.gz http://ftp.gnu.org/gnu/libiconv/libiconv-${iconv_version}.tar.gz && \
    tar -xvf libiconv.tar.gz && rm libiconv.tar.gz && mv libiconv-* iconv

# Download zlib
RUN git clone --branch v${zlib_version} https://github.com/madler/zlib.git

# Download libxml2
RUN git clone --branch ${libxml2_version} https://github.com/GNOME/libxml2.git

# Download freetype
RUN wget -O freetype.tar.gz https://download.savannah.gnu.org/releases/freetype/freetype-${freetype_version}.tar.gz \
    && tar -xzf freetype.tar.gz && rm freetype.tar.gz && mv freetype-${freetype_version} freetype

# Download fribidi
RUN wget https://github.com/fribidi/fribidi/releases/download/v${fribidi_version}/fribidi-${fribidi_version}.tar.xz \
    && tar -xJf fribidi-${fribidi_version}.tar.xz && rm fribidi-${fribidi_version}.tar.xz && mv fribidi-${fribidi_version} fribidi

# Download harfbuzz
RUN git clone --branch ${harfbuzz_version} https://github.com/harfbuzz/harfbuzz.git harfbuzz
# RUN wget https://github.com/harfbuzz/harfbuzz/releases/download/${harfbuzz_version}/harfbuzz-${harfbuzz_version}.tar.xz \
#     && tar -xJf harfbuzz-${harfbuzz_version}.tar.xz && rm harfbuzz-${harfbuzz_version}.tar.xz && mv harfbuzz-${harfbuzz_version} harfbuzz

# Download fontconfig
RUN git clone --depth=1 https://gitlab.freedesktop.org/fontconfig/fontconfig.git

# Download libass
RUN git clone --branch ${libass_version} https://github.com/libass/libass.git

# Download mp3lame
RUN wget -O mp3lame.tar.gz https://downloads.sourceforge.net/project/lame/lame/${mp3lame_version}/lame-${mp3lame_version}.tar.gz \
    && tar -xzf mp3lame.tar.gz && rm mp3lame.tar.gz && mv lame-${mp3lame_version} lame

# Download libvpx
RUN git clone --branch v${libvpx_version} https://chromium.googlesource.com/webm/libvpx.git

# Download x264
RUN git clone --branch ${x264_version} https://code.videolan.org/videolan/x264.git

# Download x265
RUN wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/${x265_version}.tar.bz2 \
    && tar xjf x265.tar.bz2 && rm x265.tar.bz2 && mv multicoreware-x265_git-* x265

# Download xvidcore
RUN wget -O xvidcore.tar.gz https://downloads.xvid.com/downloads/xvidcore-${xvid_version}.tar.gz \
    && tar -xzf xvidcore.tar.gz && rm xvidcore.tar.gz

# Download fdk-aac
RUN wget -O fdk-aac.tar.gz https://github.com/mstorsjo/fdk-aac/archive/v${fdk_aac_version}.tar.gz \
    && tar -xzf fdk-aac.tar.gz && rm fdk-aac.tar.gz && mv fdk-aac-* fdk-aac

# Download Opus
RUN git clone --branch v${opus_version} https://github.com/xiph/opus.git

# Download libwebp
RUN wget -O libwebp.tar.gz https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${libwebp_version}.tar.gz \
    && tar -xzf libwebp.tar.gz && rm libwebp.tar.gz && mv libwebp-${libwebp_version} libwebp

# Download openjpeg
RUN git clone --branch v${openjpeg_version} https://github.com/uclouvain/openjpeg.git

# Download zimg
RUN git clone --branch release-${zimg_version} https://github.com/sekrit-twc/zimg.git

# Download ffmpeg
RUN wget -O ffmpeg.tar.bz2 https://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2 \
    && tar -xjf ffmpeg.tar.bz2 && rm ffmpeg.tar.bz2 && mv ffmpeg-${ffmpeg_version} ffmpeg

# Download ffnvcodec
RUN git clone --branch n${nvcodec_version} https://github.com/FFmpeg/nv-codec-headers.git ffnvcodec


WORKDIR /output

ADD start.sh /start.sh
RUN chmod 755 /start.sh

# Set the entrypoint
CMD ["/start.sh"]
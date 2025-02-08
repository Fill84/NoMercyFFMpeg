FROM nvidia/cuda:12.6.3-devel-ubuntu24.04 AS ffmpeg-base

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0.0"
LABEL description="Cross-compile FFmpeg for Windows, Linux, Darwin and Aarch64"

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
    libogg_version=1.3.5 \
    openssl_version=3.4.0 \
    fontconfig_version=2.15.0 \
    libpciaccess_version=0.18.1 \
    xcbproto_version=1.17.0 \
    xorgproto_version=2024.1 \
    xtranx_version=1.5.2 \
    libxcb_version=1.17.0 \
    libx11_version=1.8.10 \
    libXfixed_version=6.0.1 \
    libdrm_version=2.4.124 \
    harfbuzz_version=10.1.0 \
    vulkan_headers_version=1.4.307 \
    libudfread_version=1.1.2 \
    libvorbis_version=1.3.7 \
    libvmaf_version=3.0.0 \
    avisynth_version=3.7.3 \
    chromaprint_version=1.5.1 \
    libass_version=0.17.3 \
    libva_version=2.22.0 \
    libgcrypt_version=1.11.0 \
    libbluray_version=1.3.4 \
    libcddb_version=1.3.2 \
    libcdio_version=master \
    libcdio_paranoia_version=2.0.2 \
    dav1d_version=1.5.0 \
    davs2_version=1.7 \
    rav1e_version=0.7.1 \
    libsrt_version=1.5.4 \
    twolame_version=0.4.0 \
    mp3lame_version=3.100 \
    fdk_aac_version=2.0.3 \
    opus_version=1.5.2 \
    libaom_version=3.11.0 \
    libtheora_version=1.1.1 \
    libvpx_version=1.15.0 \
    x264_version=stable \
    x265_version=master \
    xavs2_version=1.4 \
    xvid_version=1.3.7 \
    libwebp_version=1.4.0 \
    openjpeg_version=2.5.3 \
    zimg_version=3.0.5 \
    frei0r_version=2.3.3 \
    libvpl_version=2.14.0 \
    libsvtav1_version=2.3.0 \
    amf_version=1.4.35 \
    nvcodec_version=12.2.72.0 \
    leptonica_version=1.85.0 \
    libtesseract_version=5.5.0 \
    sdl2_version=2.30.10 \
    shaderc_version=2024.4 \
    spirv_cross_checkout=5e7db829a37787e096a7bfbdbdf317cd6cbe5897 \
    libplacebo_version=7.349.0

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
    libssl-dev \
    libtool \
    libxext-dev \
    meson \
    nasm \
    nvidia-cuda-toolkit \
    pkg-config \
    python3 \
    python3-dev \
    python3-venv \
    subversion \
    texinfo \
    wget \
    xtrans-dev \
    xutils-dev \
    yasm \
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

# Download libogg
RUN git clone --branch v${libogg_version} https://github.com/xiph/ogg.git libogg

# Download openssl
RUN git clone --branch openssl-${openssl_version} https://github.com/openssl/openssl.git openssl \
    && cd openssl && git submodule update --init --recursive --depth=1 && cd ..

# Download fontconfig
RUN git clone --branch ${fontconfig_version} https://gitlab.freedesktop.org/fontconfig/fontconfig.git fontconfig

# Download libpciaccess
RUN git clone --branch libpciaccess-${libpciaccess_version} https://gitlab.freedesktop.org/xorg/lib/libpciaccess.git libpciaccess

# Download xcbproto
RUN git clone --branch xcb-proto-${xcbproto_version} https://gitlab.freedesktop.org/xorg/proto/xcbproto.git xcbproto

# Download xproto
RUN git clone --branch xorgproto-${xorgproto_version} https://gitlab.freedesktop.org/xorg/proto/xorgproto.git xproto

# Download xtrans
RUN git clone --branch xtrans-${xtranx_version} https://gitlab.freedesktop.org/xorg/lib/libxtrans.git libxtrans

# Download libxcb
RUN git clone --branch libxcb-${libxcb_version} https://gitlab.freedesktop.org/xorg/lib/libxcb.git libxcb

# Download libx11
RUN git clone --branch libX11-${libx11_version} https://gitlab.freedesktop.org/xorg/lib/libx11.git libx11

# Download libxfixes
RUN git clone --branch libXfixes-${libXfixed_version} https://gitlab.freedesktop.org/xorg/lib/libxfixes.git /build/libxfixes

# Download libdrm
RUN git clone --branch libdrm-${libdrm_version} https://gitlab.freedesktop.org/mesa/drm.git libdrm

# Download harfbuzz
RUN git clone --branch ${harfbuzz_version} https://github.com/harfbuzz/harfbuzz.git harfbuzz

# Download vulkan-headers
RUN git clone --branch v${vulkan_headers_version} https://github.com/KhronosGroup/Vulkan-Headers.git vulkan-headers

# Download libudfread
RUN git clone --branch ${libudfread_version} https://code.videolan.org/videolan/libudfread libudfread

# Download libvorbis
RUN git clone --branch v${libvorbis_version} https://github.com/xiph/vorbis.git libvorbis

# Download libvmaf
RUN git clone --branch v${libvmaf_version} https://github.com/Netflix/vmaf.git libvmaf

# Download avisynth
RUN git clone --branch v${avisynth_version} https://github.com/AviSynth/AviSynthPlus.git avisynth

# Download chromaprint
RUN git clone --branch v${chromaprint_version} https://github.com/acoustid/chromaprint.git chromaprint

# Download shaderc
RUN git clone --branch v${shaderc_version} https://github.com/google/shaderc.git

# Download libass
RUN git clone --branch ${libass_version} https://github.com/libass/libass.git libass

# Download libva
RUN git clone --branch ${libva_version} https://github.com/intel/libva.git libva

# Download libgpg-error
RUN git clone https://github.com/gpg/libgpg-error.git libgpg-error

# Download libgcrypt
RUN wget https://github.com/gpg/libgcrypt/archive/refs/tags/libgcrypt-${libgcrypt_version}.tar.gz && \
    tar -xzf libgcrypt-${libgcrypt_version}.tar.gz && rm -f libgcrypt-${libgcrypt_version}.tar.gz && mv libgcrypt-libgcrypt-${libgcrypt_version} libgcrypt

# Download libbdplus
RUN git clone https://code.videolan.org/videolan/libbdplus.git libbdplus

# Download libaacs
RUN git clone https://code.videolan.org/videolan/libaacs.git libaacs

# Download libbluray
RUN git clone --branch ${libbluray_version} https://code.videolan.org/videolan/libbluray.git libbluray

RUN wget -O libcddb.tar.gz https://sourceforge.net/projects/libcddb/files/libcddb/${libcddb_version}/libcddb-${libcddb_version}.tar.gz/download \
    && tar -xvf libcddb.tar.gz && rm libcddb.tar.gz \
    && mv libcddb-* libcddb

# Download libcdio
RUN git clone --branch ${libcdio_version} https://github.com/libcdio/libcdio.git libcdio

# Download libcdio-paranoia
RUN git clone --branch release-10.2+${libcdio_paranoia_version} https://github.com/libcdio/libcdio-paranoia.git libcdio-paranoia

# Download dav1d
RUN git clone --branch ${dav1d_version} https://code.videolan.org/videolan/dav1d.git libdav1d

# Download dav2
RUN git clone --branch ${davs2_version} https://github.com/pkuvcl/davs2.git libdavs2

# Download rav1e
RUN git clone --branch v${rav1e_version} https://github.com/xiph/rav1e.git librav1e

# Download libsrt
RUN git clone --branch v${libsrt_version} https://github.com/Haivision/srt.git libsrt

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

# Download libaom
RUN git clone --branch v${libaom_version} https://aomedia.googlesource.com/aom libaom

# Download libtheora
RUN git clone --branch v${libtheora_version} https://github.com/xiph/theora.git libtheora

# Download libsvtav1
RUN git clone --branch v${libsvtav1_version} https://gitlab.com/AOMediaCodec/SVT-AV1.git libsvtav1

# Download libvpx
RUN git clone --branch v${libvpx_version} https://chromium.googlesource.com/webm/libvpx.git libvpx

# Download x264
RUN git clone --branch ${x264_version} https://code.videolan.org/videolan/x264.git x264

# Download x265
RUN wget -O x265.tar.bz2 https://bitbucket.org/multicoreware/x265_git/get/${x265_version}.tar.bz2 \
    && tar xjf x265.tar.bz2 && rm x265.tar.bz2 && mv multicoreware-x265_git-* x265

# Download xavs2
RUN git clone --branch ${xavs2_version} https://github.com/pkuvcl/xavs2.git libxavs2

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

# Download frei0r
RUN git clone --branch v${frei0r_version} https://github.com/dyne/frei0r.git frei0r

# Download libvpl
RUN git clone --branch v${libvpl_version} https://github.com/intel/libvpl.git libvpl

# Download amf
RUN git clone --branch v${amf_version} https://github.com/GPUOpen-LibrariesAndSDKs/AMF.git amf

# Download ffnvcodec
RUN git clone --branch n${nvcodec_version} https://github.com/FFmpeg/nv-codec-headers.git ffnvcodec

# Download leptonica
RUN git clone --branch ${leptonica_version} https://github.com/DanBloomberg/leptonica.git leptonica

# Download libtesseract (for OCR)
RUN git clone --branch ${libtesseract_version} https://github.com/tesseract-ocr/tesseract.git libtesseract

# Download SDL2
RUN git clone --branch release-${sdl2_version} https://github.com/libsdl-org/SDL.git sdl2

# Download spirv-cross
RUN git clone https://github.com/KhronosGroup/SPIRV-Cross.git spirv-cross && \
    cd spirv-cross && git checkout ${spirv_cross_checkout} && cd ..

# Download libplacebo
RUN git clone --branch release https://code.videolan.org/videolan/libplacebo.git libplacebo

# Download ffmpeg
RUN wget -O ffmpeg.tar.bz2 https://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2 \
    && tar -xjf ffmpeg.tar.bz2 && rm ffmpeg.tar.bz2 && mv ffmpeg-${ffmpeg_version} ffmpeg

RUN mkdir -p /output

WORKDIR /

CMD ["rm", "-f", "/output/*.tar.gz"]
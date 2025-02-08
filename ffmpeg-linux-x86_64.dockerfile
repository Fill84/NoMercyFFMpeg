# Create a Linux ffmpeg build
FROM nomercyentertainment/ffmpeg-base AS linux

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0.0"
LABEL description="FFmpeg for Linux x86_64"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ gcc \
    && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /build

# Set environment variables for building ffmpeg
ENV PREFIX=/ffmpeg_build/linux
ENV ARCH=x86_64
ENV CROSS_PREFIX=${ARCH}-linux-gnu-
ENV CC=${CROSS_PREFIX}gcc
ENV CXX=${CROSS_PREFIX}g++
ENV LD=${CROSS_PREFIX}ld
ENV AR=${CROSS_PREFIX}gcc-ar
ENV RANLIB=${CROSS_PREFIX}gcc-ranlib
ENV STRIP=${CROSS_PREFIX}strip
ENV NM=${CROSS_PREFIX}gcc-nm
# ENV WINDRES=${CROSS_PREFIX}windres
# ENV DLLTOOL=${CROSS_PREFIX}dlltool
ENV STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition"
ENV STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
ENV PKG_CONFIG=pkg-config
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV PATH="${PREFIX}/bin:${PATH}"
ENV CFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread"
ENV CXXFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread" 
ENV LDFLAGS="-static-libgcc -static-libstdc++ -L${PREFIX}/lib -O2 -pipe -fstack-protector-strong -fstack-clash-protection -Wl,-z,relro,-z,now -pthread -lm"

# Create the build directory
RUN mkdir -p ${PREFIX}

# Create Meson cross file for Linux
RUN echo "[binaries]" > /build/cross_file.txt && \
    echo "c = '${CC}'" >> /build/cross_file.txt && \
    echo "cpp = '${CXX}'" >> /build/cross_file.txt && \
    echo "ld = '${LD}'" >> /build/cross_file.txt && \
    echo "ar = '${AR}'" >> /build/cross_file.txt && \
    echo "ranlib = '${RANLIB}'" >> /build/cross_file.txt && \
    echo "strip = '${STRIP}'" >> /build/cross_file.txt && \
    echo "pkgconfig = '${PKG_CONFIG}'" >> /build/cross_file.txt && \
    echo "" >> /build/cross_file.txt && \
    echo "[host_machine]" >> /build/cross_file.txt && \
    echo "system = 'linux'" >> /build/cross_file.txt && \
    echo "cpu_family = '${ARCH}'" >> /build/cross_file.txt && \
    echo "cpu = '${ARCH}'" >> /build/cross_file.txt && \
    echo "endian = 'little'" >> /build/cross_file.txt

ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release"

# iconv
# libxml2
# zlib
# fftw3
# libfreetype
# fribidi
# libogg
RUN \
    # iconv
    cd /build/iconv \
    && ./configure --prefix=${PREFIX} --enable-extra-encodings --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/iconv \
    \
    # libxml2
    && cd /build/libxml2 \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxml2 \
    \
    # zlib
    && cd /build/zlib \
    && ./configure --prefix=${PREFIX} --static \
    && make -j$(nproc) && make install \
    && rm -rf /build/zlib \
    \
    # fftw3
    && cd /build/fftw3 \
    && ./bootstrap.sh --prefix=${PREFIX} --enable-static --disable-shared --enable-maintainer-mode --disable-fortran \
    --disable-doc --with-our-malloc --enable-threads --with-combined-threads --with-incoming-stack-boundary=2 \
    --enable-sse2 --enable-avx --enable-avx2 \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/fftw3 \
    \
    # libfreetype
    && cd /build/freetype \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    && make -j$(nproc) && make install \
    && rm -rf /build/freetype \
    \
    # fribidi
    && cd /build/fribidi \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    && make -j$(nproc) && make install \
    && rm -rf /build/fribidi \
    \
    # libogg
    && cd /build/libogg \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libogg

# openssl
ENV OLD_CFLAGS=${CFLAGS}
ENV OLD_CXXFLAGS=${CXXFLAGS}
ENV CFLAGS="${CFLAGS} -fno-strict-aliasing"
ENV CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"
RUN cd /build/openssl \
    && ./Configure threads zlib no-shared enable-camellia enable-ec enable-srp --prefix=${PREFIX} linux-x86_64 --libdir=${PREFIX}/lib \
    --cross-compile-prefix='' \
    && sed -i -e "/^CFLAGS=/s|=.*|=${CFLAGS}|" -e "/^LDFLAGS=/s|=[[:space:]]*$|=${LDFLAGS}|" Makefile \
    && make -j$(nproc) build_sw && make install_sw \
    && rm -rf /build/openssl
ENV CFLAGS=${OLD_CFLAGS}
ENV CXXFLAGS=${OLD_CXXFLAGS}

# fontconfig
RUN cd /build/fontconfig \
    && ./autogen.sh --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared --sysconfdir=/etc --localstatedir=/var \
    && ./configure --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared --sysconfdir=/etc --localstatedir=/var \
    && make -j$(nproc) && make install \
    && rm -rf /build/fontconfig

# libpciaccess
# xcbproto
# xproto
# xtrans
# libxcb
# libx11
# libxfixes
# libdrm
RUN \
    # libpciaccess
    cd /build/libpciaccess \
    && meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -j$(nproc) -C build && ninja -C build install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libpciaccess.pc \
    && rm -rf /build/libpciaccess \
    \
    # xcbproto
    && cd /build/xcbproto \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && mv ${PREFIX}/share/pkgconfig/xcb-proto.pc ${PREFIX}/lib/pkgconfig/xcb-proto.pc \
    && rm -rf /build/xcbproto \
    \
    # xproto
    && cd /build/xproto \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && mv ${PREFIX}/share/pkgconfig/xproto.pc ${PREFIX}/lib/pkgconfig/xproto.pc \
    && rm -rf /build/xproto \
    \
    # xtrans
    && cd /build/libxtrans \
    && ./autogen.sh --prefix=${PREFIX} --without-xmlto --without-fop --without-xsltproc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --without-xmlto --without-fop --without-xsltproc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && cp -r ${PREFIX}/share/aclocal/. ${PREFIX}/lib/aclocal \
    && rm -rf /build/libxtrans \
    \
    # libxcb
    && cd /build/libxcb \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-devel-docs \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-devel-docs \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxcb \
    \
    # libx11
    && cd /build/libx11 \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --without-xmlto --without-fop --without-xsltproc --without-lint --disable-specs --enable-ipv6 \
    --host=${CROSS_PREFIX%-} \
    --disable-malloc0returnsnull \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --without-xmlto --without-fop --without-xsltproc --without-lint --disable-specs --enable-ipv6 \
    --host=${CROSS_PREFIX%-} \
    --disable-malloc0returnsnull \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/x11.pc \
    && rm -rf /build/libx11 \
    \
    # libxfixes
    && cd /build/libxfixes \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/xfixes.pc \
    && rm -rf /build/libxfixes \
    \
    # libdrm
    && cd /build/libdrm \
    && mkdir build && cd build \
    && meson --prefix=${PREFIX} --buildtype=release \
    -Ddefault_library=static -Dudev=false -Dcairo-tests=disabled \
    -Dvalgrind=disabled -Dexynos=disabled -Dfreedreno=disabled \
    -Domap=disabled -Detnaviv=disabled -Dintel=enabled \
    -Dnouveau=enabled -Dradeon=enabled -Damdgpu=enabled \
    --cross-file=../../cross_file.txt .. \
    && ninja -j$(nproc) && ninja install install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libdrm.pc \
    && rm -rf /build/libdrm

# harfbuzz
RUN cd /build/harfbuzz \
    && meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -j$(nproc) -C build && ninja -C build install \
    && rm -rf /build/harfbuzz

# libudfread
RUN cd /build/libudfread \
    && ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(nproc) && make install \
    && ln -s libudfread.pc ${PREFIX}/lib/pkgconfig/udfread.pc \
    && rm -rf /build/libudfread

# libvorbis
RUN cd /build/libvorbis \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-oggtest \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-oggtest \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libvorbis

# libvmaf
RUN cd /build/libvmaf \
    && mkdir build && cd build \
    && meson --prefix=${PREFIX} \
    --buildtype=release --default-library=static -Dbuilt_in_models=true -Denable_tests=false -Denable_docs=false -Denable_avx512=true -Denable_float=true \
    --cross-file=../../cross_file.txt ../libvmaf \
    && ninja -j$(nproc) && ninja install \
    && sed -i 's/Libs.private:/Libs.private: -lstdc++/; t; $ a Libs.private: -lstdc++' ${PREFIX}/lib/pkgconfig/libvmaf.pc \
    && rm -rf /build/libvmaf

# avisynth
RUN cd /build/avisynth \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DHEADERS_ONLY=ON \
    && make -j$(nproc) && make VersionGen install \
    && rm -rf /build/avisynth

# chromaprint
RUN cd /build/chromaprint \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_TOOLS=OFF \
    -DBUILD_TESTS=OFF \
    -DFFT_LIB=fftw3 \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lfftw3 -lstdc++" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc \
    && echo "Cflags.private: -DCHROMAPRINT_NODLL" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc \
    && rm -rf /build/chromaprint

# libass
RUN cd /build/libass \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(nproc) && make install \
    && rm -rf /build/libass

# libva
RUN cd /build/libva \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-x11 --enable-drm --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-x11 --enable-drm --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libva.pc \
    && rm -rf /build/libva

# libgpg-error
# libgcrypt
# libbdplus
# libaacs
RUN \
    # libgpg-error
    cd /build/libgpg-error \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libgpg-error.pc \
    && rm -rf /build/libgpg-error \
    \
    # libgcrypt
    && cd /build/libgcrypt \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libgcrypt.pc \
    \
    && echo '#!/bin/sh' > /usr/local/bin/libgcrypt-config \
    && echo 'pkg-config libgcrypt "$@"' >> /usr/local/bin/libgcrypt-config \
    && chmod +x /usr/local/bin/libgcrypt-config \
    \
    && echo '#!/bin/sh' > /usr/local/bin/gpg-error-config \
    && echo 'pkg-config libgpg-error "$@"' >> /usr/local/bin/gpg-error-config \
    && chmod +x /usr/local/bin/gpg-error-config \
    && rm -rf /build/libgcrypt \
    \
    # libbdplus
    && cd /build/libbdplus \
    && ./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libbdplus.pc \
    && rm -rf /build/libbdplus \
    \
    # libaacs
    && cd /build/libaacs \
    && ./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libaacs.pc \
    && rm -rf /build/libaacs

# libbluray
ENV EXTRA_LIBS="-L${PREFIX}/lib -laacs -lbdplus"
RUN cd /build/libbluray \
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.c \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.h \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/disc.c \
    && cd /build/libbluray \
    && export EXTRA_LIBS=${EXTRA_LIBS} \
    && ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -laacs -lbdplus -lstdc++" >> ${PREFIX}/lib/pkgconfig/libbluray.pc \
    && export EXTRA_LIBS="" \
    && rm -rf /build/libbluray
ENV EXTRA_LIBS=""

# libcdio
# libcddb
# libcdio-paranoia
RUN \
    # libcddb
    cd /build/libcddb \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libcddb.pc \
    && rm -rf /build/libcddb \
    \
    # libcdio
    && cd /build/libcdio \
    && touch src/cd-drive.1 src/cd-info.1 src/cd-read.1 src/iso-info.1 src/iso-read.1 \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libcdio.pc \
    && rm -rf /build/libcdio \
    \
    # libcdio-paranoia
    && cd /build/libcdio-paranoia \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libcdio_paranoia.pc \
    && rm -rf /build/libcdio-paranoia

# libdav1d
RUN cd /build/libdav1d \
    && mkdir build && cd build \
    && meson --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../../cross_file.txt .. \
    && ninja -j$(nproc) && ninja install \
    && rm -rf /build/libdav1d

# libdavs2
RUN cd /build/libdavs2/build/linux \
    && sed -i -e 's/EGIB/bss/g' -e 's/naidnePF/bss/g' configure \
    && ./configure --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libdavs2

# librav1e
RUN cd /build/librav1e \
    && cargo cinstall -v --prefix=${PREFIX} --library-type=staticlib --crt-static --release \
    && sed -i 's/-lgcc_s//' ${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/rav1e.pc \
    && cp ${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/rav1e.pc ${PREFIX}/lib/pkgconfig/rav1e.pc \
    && rm -rf /build/librav1e

# libsrt
RUN cd /build/libsrt \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_CXX_DEPS=ON -DUSE_STATIC_LIBSTDCXX=ON -DENABLE_ENCRYPTION=ON -DENABLE_APPS=OFF \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/srt.pc \
    && rm -rf /build/libsrt

# twolame
RUN cd /build/twolame \
    && NOCONFIGURE=1 ./autogen.sh \
    && touch doc/twolame.1 \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-sndfile \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && sed -i 's/Cflags:/Cflags: -DLIBTWOLAME_STATIC/' ${PREFIX}/lib/pkgconfig/twolame.pc \
    && rm -rf /build/twolame
ENV CFLAGS="${CFLAGS} -DLIBTWOLAME_STATIC"

# mp3lame
RUN cd /build/lame \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --enable-nasm --disable-gtktest --disable-cpml --disable-frontend --disable-decoder \
    && make -j$(nproc) && make install\
    && rm -rf /build/lame

# fdk-aac
RUN cd /build/fdk-aac \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    && make -j$(nproc) && make install \
    && rm -rf /build/fdk-aac

# opus
RUN cd /build/opus \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    && make -j$(nproc) && make install \
    && rm -rf /build/opus

# libaom
RUN cd /build/libaom \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DENABLE_EXAMPLES=NO -DENABLE_TESTS=NO -DENABLE_TOOLS=NO -DCONFIG_TUNE_VMAF=1 \
    && make -j$(nproc) && make install \
    && echo "Requires.private: libvmaf" >> ${PREFIX}/lib/pkgconfig/aom.pc \
    && rm -rf /build/libaom

# libtheora
RUN cd /build/libtheora \
    && ./autogen.sh --prefix=${PREFIX} \
    --disable-shared \
    --enable-static \
    --with-pic \
    --disable-examples \
    --disable-oggtest \
    --disable-vorbistest \
    --disable-spec \
    --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} \
    --disable-shared \
    --enable-static \
    --with-pic \
    --disable-examples \
    --disable-oggtest \
    --disable-vorbistest \
    --disable-spec \
    --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libtheora

# libsvtav1
RUN cd /build/libsvtav1 \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_APPS=OFF -DBUILD_EXAMPLES=OFF -DENABLE_AVX512=ON \
    && make -j$(nproc) && make install \
    && rm -rf /build/libsvtav1

# libvpx
RUN cd /build/libvpx \
    && ./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    && make -j$(nproc) && make install \
    && rm -rf /build/libvpx

# x264
RUN cd /build/x264 \
    && ./configure --prefix=${PREFIX} --disable-cli --enable-static --enable-pic --disable-shared --disable-lavf --disable-swscale \
    && make -j$(nproc) && make install \
    && rm -rf /build/x264

# x265
ENV CMAKE_X265_ARG="${CMAKE_COMMON_ARG} -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy"
RUN \
    # build x265 12bit
    cd /build/x265 \
    && rm -rf build/linux/12bit build/linux/10bit build/linux/8bit \
    && mkdir -p build/linux/12bit build/linux/10bit build/linux/8bit \
    && cd build/linux/12bit \
    && cmake ${CMAKE_X265_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON -S ../../../source -B . \
    && make -j$(nproc) \
    # build x265 10bit
    && cd ../10bit \
    && cmake ${CMAKE_X265_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -S ../../../source -B . \
    && make -j$(nproc) \
    # build x265 8bit
    && cd ../8bit \
    && mv ../12bit/libx265.a ./libx265_main12.a && mv ../10bit/libx265.a ./libx265_main10.a \
    && cmake ${CMAKE_X265_ARG} -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S ../../../source -B . \
    && make -j$(nproc) \
    # install x265
    && mv libx265.a libx265_main.a \
    && { \
    echo "CREATE libx265.a"; \
    echo "ADDLIB libx265_main.a"; \
    echo "ADDLIB libx265_main10.a"; \
    echo "ADDLIB libx265_main12.a"; \
    echo "SAVE"; \
    echo "END"; \
    } | ar -M \
    && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc" \
    && rm -rf /build/x265

# xavs2
RUN cd /build/libxavs2/build/linux \
    && ./configure --prefix=${PREFIX} \
    --disable-cli --enable-static --enable-pic --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --disable-lsmash --extra-asflags="-w-macro-params-legacy" \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxavs2

# xvid
ENV OLD_CFLAGS=${CFLAGS}
ENV CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"
RUN cd /build/xvidcore \
    && cd build/generic \
    && CFLAGS=${CFLAGS} \
    ./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \ 
    CC=${CC} \
    CXX=${CXX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/xvidcore
ENV CFLAGS=${OLD_CFLAGS}

# libwebp
# openjpeg
# zimg
# ffnvcodec
# cuda
RUN \
    # libwebp
    cd /build/libwebp \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    && make -j$(nproc) && make install \
    && rm -rf /build/libwebp \
    \
    # openjpeg
    && cd /build/openjpeg \
    && mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_PKGCONFIG_FILES=ON \
    -DBUILD_TESTING=OFF \
    && make -j$(nproc) && make install \
    && rm -rf /build/openjpeg \
    \
    # zimg
    && cd /build/zimg \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(nproc) && make install \
    && rm -rf /build/zimg \
    \
    # ffnvcodec
    && cd /build/ffnvcodec \
    && make PREFIX=${PREFIX} install \
    && rm -rf /build/ffnvcodec \
    \
    # cuda
    && cp -R /usr/local/cuda/include/* ${PREFIX}/include \
    && cp -R /usr/local/cuda/lib64/* ${PREFIX}/lib

# frei0r
RUN cd /build/frei0r \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    # && make -j$(nproc) && make install \
    && cp frei0r.pc ${PREFIX}/lib/pkgconfig/frei0r.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/frei0r.pc \
    && cp ../include/frei0r.h ${PREFIX}/include \
    && rm -rf /build/frei0r

# libvpl
RUN cd /build/libvpl \
    && mkdir -p build && cd build \
    && cmake -GNinja -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DCMAKE_INSTALL_BINDIR=${PREFIX}/bin -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib \
    -DBUILD_DISPATCHER=ON -DBUILD_DEV=ON \
    -DBUILD_PREVIEW=OFF -DBUILD_TOOLS=OFF -DBUILD_TOOLS_ONEVPL_EXPERIMENTAL=OFF -DINSTALL_EXAMPLE_CODE=OFF \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF \
    && ninja -j$(nproc) && ninja install \
    && rm -rf /build/libvpl ${PREFIX}/{etc,share}

# amf
RUN cd /build/amf \
    && mv amf/public/include ${PREFIX}/include/AMF

# libjpeg-turbo
RUN wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.0.2.tar.gz -O libjpeg-turbo-3.0.2.tar.gz \
    && tar xzf libjpeg-turbo-3.0.2.tar.gz \
    && cd libjpeg-turbo-3.0.2 \
    && mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libjpeg-turbo-3.0.2

# libtiff
RUN wget https://download.osgeo.org/libtiff/tiff-4.6.0.tar.gz \
    && tar xzf tiff-4.6.0.tar.gz \
    && cd tiff-4.6.0 \
    && ./configure --host=${CROSS_PREFIX%-} --prefix=${PREFIX} \
    --enable-static --disable-shared \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libtiff-4.pc \
    && rm -rf /build/tiff-4.6.0

# libtesseract (tesseract-ocr)
# leptonica
RUN \
    # leptonica
    cd /build/leptonica \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --disable-programs \
    --without-giflib \
    --without-jpeg \
    --without-libopenjpeg \
    --without-libwebp \
    --without-libtiff \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --disable-programs \
    --without-giflib \
    --without-jpeg \
    --without-libopenjpeg \
    --without-libwebp \
    --without-libtiff \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/lept.pc \
    && cp ${PREFIX}/lib/pkgconfig/lept.pc ${PREFIX}/lib/pkgconfig/liblept.pc \
    && rm -rf /build/leptonica && cd /build \
    \
    # libtesseract (tesseract-ocr)
    && cd /build/libtesseract \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --disable-doc \
    --without-archive \
    --disable-openmp \
    --without-curl \
    --with-extra-includes=${PREFIX}/include \
    --with-extra-libraries=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --disable-doc \
    --without-archive \
    --disable-openmp \
    --without-curl \
    --with-extra-includes=${PREFIX}/include \
    --with-extra-libraries=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/tesseract.pc \
    && cp ${PREFIX}/lib/pkgconfig/tesseract.pc ${PREFIX}/lib/pkgconfig/libtesseract.pc \
    && rm -rf /build/libtesseract

# sdl2
# xxf86vm
# xrender
# xscrnsaver
# xrandr
# xi
# xinerama
# xcursor
# libsamplerate
# libpulse
RUN \
    # xxf86vm
    git clone --branch libXxf86vm-1.1.6 https://gitlab.freedesktop.org/xorg/lib/libxxf86vm.git /build/libxxf86vm \
    && cd /build/libxxf86vm \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxxf86vm && cd /build \
    \
    # xrender
    && git clone --branch libXrender-0.9.12 https://gitlab.freedesktop.org/xorg/lib/libxrender.git /build/libxrender \
    && cd /build/libxrender \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxrender && cd /build \
    \
    # xscrnsaver
    && git clone --branch libXScrnSaver-1.2.4 https://gitlab.freedesktop.org/xorg/lib/libxscrnsaver.git /build/libxscrnsaver \
    && cd /build/libxscrnsaver \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxscrnsaver && cd /build \
    \
    # xrandr
    && git clone --branch libXrandr-1.5.4 https://gitlab.freedesktop.org/xorg/lib/libxrandr.git /build/libxrandr \
    && cd /build/libxrandr \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxrandr && cd /build \
    \
    # xi
    && git clone --branch libXi-1.8.2 https://gitlab.freedesktop.org/xorg/lib/libxi.git /build/libxi \
    && cd /build/libxi \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxi && cd /build \
    \
    # xinerama
    && git clone --branch libXinerama-1.1.5 https://gitlab.freedesktop.org/xorg/lib/libxinerama.git /build/libxinerama \
    && cd /build/libxinerama \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxinerama && cd /build \
    \
    # xcursor
    && git clone --branch libXcursor-1.2.3 https://gitlab.freedesktop.org/xorg/lib/libxcursor.git /build/libxcursor \
    && cd /build/libxcursor \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxcursor && cd /build \
    \
    # libsamplerate
    && git clone --branch 0.2.2 https://github.com/libsndfile/libsamplerate.git /build/libsamplerate \
    && mkdir -p /build/libsamplerate/build && cd /build/libsamplerate/build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_TESTING=OFF -DLIBSAMPLERATE_EXAMPLES=OFF -DLIBSAMPLERATE_INSTALL=ON \
    && make -j$(nproc) && make install \
    && rm -rf /build/libsamplerate && cd /build \
    \ 
    # libpulse
    && git clone --branch stable-16.x https://gitlab.freedesktop.org/pulseaudio/pulseaudio.git /build/pulseaudio \
    && cd /build/pulseaudio \
    && echo > src/utils/meson.build \
    && echo > src/pulsecore/sndfile-util.c \
    && echo > src/pulsecore/sndfile-util.h \
    && sed -ri -e 's/(sndfile_dep = .*)\)/\1, required : false)/' meson.build \
    && sed -ri -e 's/shared_library/library/g' src/meson.build src/pulse/meson.build \
    && mkdir -p build && cd build \
    && meson --prefix=${PREFIX} \
    --buildtype=release \
    --default-library=static \
    -Ddaemon=false \
    -Dclient=true \
    -Ddoxygen=false \
    -Dgcov=false \
    -Dman=false \
    -Dtests=false \
    -Dipv6=true \
    -Dopenssl=enabled \
    --cross-file=../../cross_file.txt .. \
    && ninja -j$(nproc) && ninja install \
    && echo "Libs.private: -lstdc++ -ldl -lrt" >> ${PREFIX}/lib/pkgconfig/libpulse.pc \
    && echo "Libs.private: -lstdc++ -ldl -lrt" >> ${PREFIX}/lib/pkgconfig/libpulse-simple.pc \
    && rm -rf /build/pulseaudio && cd /build \
    \    
    # sdl2
    && cd /build/sdl2 \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_STATIC_PIC=ON \
    -DSDL_TEST=OFF \
    -DSDL_X11=ON \
    -DSDL_X11_SHARED=OFF \
    -DHAVE_XGENERICEVENT=TRUE \
    -DSDL_VIDEO_DRIVER_X11_HAS_XKBKEYCODETOKEYSYM=1 \
    -DSDL_PULSEAUDIO=ON \
    -DSDL_PULSEAUDIO_SHARED=OFF \
    && make -j$(nproc) && make install \
    && sed -ri -e 's/\-Wl,\-\-no\-undefined.*//' -e 's/ \-l\/.+?\.a//g' ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && echo 'Requires: libpulse-simple xxf86vm xscrnsaver xrandr xfixes xi xinerama xcursor' >> ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && sed -ri -e 's/ -lSDL2//g' -e 's/Libs: /Libs: -lSDL2 /' ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && echo 'Requires: samplerate' >> ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && rm -rf /build/sdl2 && cd /build

# vulkan-headers
# shaderc
# spirv-cross
# libplacebo
RUN cd /build/vulkan-headers \
    && find . -type f -name '*' -exec sed -i 's/-lshaderc_shared/-lshaderc_combined/' {} + \
    && mkdir build && cd build \
    && cmake -GNinja -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_TESTING=OFF \
    && ninja -j$(nproc) && ninja install \
    && rm -rf /build/vulkan-headers \
    && echo "prefix=${PREFIX}" > ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "exec_prefix=\${prefix}" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "libdir=\${prefix}/lib" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "includedir=\${prefix}/include" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "Name: Vulkan" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "Description: Vulkan Headers" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "Version: 1.4.307" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "Libs: -L\${libdir} -lvulkan" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    && echo "Cflags: -I\${includedir}" >> ${PREFIX}/lib/pkgconfig/vulkan.pc \
    \
    # shaderc
    && cd /build/shaderc \
    && ./utils/git-sync-deps \
    && find . -type f -name '*' -exec sed -i 's/-lshaderc_shared/-lshaderc_combined/' {} + \
    && mkdir -p build && cd build \
    && cmake -GNinja -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
    -DENABLE_EXCEPTIONS=ON -DENABLE_CTEST=OFF -DENABLE_GLSLANG_BINARIES=OFF -DSPIRV_SKIP_EXECUTABLES=ON \
    -DSPIRV_TOOLS_BUILD_STATIC=ON -DBUILD_SHARED_LIBS=OFF \
    -DSHADERC_SKIP_TESTS=ON -DSHADERC_ENABLE_SHARED_CRT=ON \
    && ninja -j$(nproc) && ninja install \
    && cp libshaderc_util/libshaderc_util.a ${PREFIX}/lib \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/shaderc.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/shaderc_static.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/shaderc_combined.pc \
    && rm -rf /build/shaderc \
    \
    # spirv-cross
    && cd /build/spirv-cross \
    && VER_MAJ="$(grep 'set(spirv-cross-abi-major' CMakeLists.txt | sed -re 's/.* ([0-9]+)\)/\1/')" \
    VER_MIN="$(grep 'set(spirv-cross-abi-minor' CMakeLists.txt | sed -re 's/.* ([0-9]+)\)/\1/')" \
    VER_PCH="$(grep 'set(spirv-cross-abi-patch' CMakeLists.txt | sed -re 's/.* ([0-9]+)\)/\1/')" \
    VER_FULL="$VER_MAJ.$VER_MIN.$VER_PCH" \
    && find . -type f -name '*' -exec sed -i 's/-lshaderc_shared/-lshaderc_combined/' {} + \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DSPIRV_CROSS_SHARED=OFF -DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_FORCE_PIC=ON -DSPIRV_CROSS_ENABLE_CPP=OFF \
    && make -j$(nproc) && make install \
    && echo "prefix=${PREFIX}" > ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "exec_prefix=\${prefix}" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "libdir=\${prefix}/lib" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "sharedlibdir=\${prefix}/lib" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "includedir=\${prefix}/include/spirv_cross" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Name: spirv-cross-c-shared" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Description: C API for SPIRV-Cross" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Version: ${VER_FULL}" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Requires:" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Libs: -L\${libdir} -L\${sharedlibdir} -lspirv-cross-c -lspirv-cross-glsl -lspirv-cross-hlsl -lspirv-cross-reflect -lspirv-cross-msl -lspirv-cross-util -lspirv-cross-core -lstdc++" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && echo "Cflags: -I\${includedir}" >> ${PREFIX}/lib/pkgconfig/spirv-cross.pc \
    && cp ${PREFIX}/lib/pkgconfig/spirv-cross.pc ${PREFIX}/lib/pkgconfig/spirv-cross-c-shared.pc \
    && rm -rf /build/spirv-cross \
    \
    # libplacebo
    && cd /build/libplacebo \
    && git submodule update --init --recursive \
    && sed -i 's/DPL_EXPORT/DPL_STATIC/' src/meson.build \
    && find . -type f -name '*' -exec sed -i 's/-lshaderc_shared/-lshaderc_combined/' {} + \
    && mkdir -p build && cd build \
    && meson --prefix=${PREFIX} \
    --buildtype=release \
    --default-library=static \
    -Dvulkan=enabled \
    -Dvk-proc-addr=disabled \
    -Dvulkan-registry=${PREFIX}/share/vulkan/registry/vk.xml \
    -Dshaderc=enabled \
    -Dglslang=disabled \
    -Ddemos=false \
    -Dtests=false \
    -Dbench=false \
    -Dfuzz=false \
    --cross-file=../../cross_file.txt .. \
    && ninja -j$(nproc) && ninja install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libplacebo.pc \
    && sed -i 's/-lshaderc_shared/-lshaderc_combined/' ${PREFIX}/lib/pkgconfig/libplacebo.pc \
    && rm -rf /build/libplacebo

# ffmpeg
RUN cd /build/ffmpeg \
    && ./configure --pkg-config-flags=--static \
    --arch=${ARCH} \
    --target-os=linux \
    --cross-prefix=${CROSS_PREFIX} \
    --pkg-config=pkg-config \
    --prefix=${PREFIX} \
    --enable-cross-compile \
    --disable-shared \
    --enable-ffplay \
    --enable-static \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --enable-iconv \
    --enable-libxml2 \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-fontconfig \
    --enable-libtesseract \
    --enable-libdrm \
    --enable-libvorbis \
    --enable-libvmaf \
    --enable-avisynth \
    --enable-chromaprint \
    --enable-libass \
    --enable-vaapi \
    --enable-libbluray \
    --enable-libcdio \
    --enable-libdav1d \
    --enable-libdavs2 \
    --enable-librav1e \
    --enable-libsrt \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libfdk-aac \
    --enable-libopus \
    --enable-libaom \
    --enable-libtheora \
    --enable-libsvtav1 \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxavs2 \
    --enable-libxvid \
    --enable-libwebp \
    --enable-libopenjpeg \
    --enable-libzimg \
    --enable-frei0r \
    --enable-libvpl \
    --enable-amf \
    --enable-ffnvcodec \
    --enable-nvdec \
    --enable-nvenc \
    --enable-cuda \
    --enable-cuda-nvcc \
    --enable-cuvid \
    --enable-sdl2 \
    --enable-vulkan \
    --enable-libshaderc \
    --enable-libplacebo \
    --enable-runtime-cpudetect \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I${PREFIX}/include" \
    --extra-ldflags="-static -static-libgcc -static-libstdc++ -L${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(nproc) && make install \
    && rm -rf /build/ffmpeg

# copy ffmpeg binaries
# cleanup
# create tarball
# cleanup
RUN mkdir -p /ffmpeg/linux/${ARCH} \
    && cp ${PREFIX}/bin/ffplay /ffmpeg/linux/${ARCH} \
    && cp ${PREFIX}/bin/ffmpeg /ffmpeg/linux/${ARCH} \
    && cp ${PREFIX}/bin/ffprobe /ffmpeg/linux/${ARCH} \
    \
    # cleanup
    && rm -rf ${PREFIX} /build \
    \
    && mkdir -p /build/linux /output \
    # create tarball
    && tar -czf /build/ffmpeg-7.1-linux-${ARCH}.tar.gz \
    -C /ffmpeg/linux/${ARCH} . \
    && cp /build/ffmpeg-7.1-linux-${ARCH}.tar.gz /output \
    \
    # cleanup
    && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    \
    && cp /ffmpeg/linux/${ARCH} /build/linux -r

# final stage
FROM debian AS final

# copy ffmpeg binaries
COPY --from=linux /build /build

CMD ["cp", "/build/ffmpeg-7.1-linux-x86_64.tar.gz", "/output"]
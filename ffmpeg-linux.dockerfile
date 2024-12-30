# Create a Linux ffmpeg build
FROM nomercyffmpeg_ffmpeg-base AS linux

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0"
LABEL description="FFmpeg for Linux"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

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
RUN echo "[binaries]" > cross_file.txt && \
    echo "c = '${CC}'" >> cross_file.txt && \
    echo "cpp = '${CXX}'" >> cross_file.txt && \
    echo "ld = '${LD}'" >> cross_file.txt && \
    echo "ar = '${AR}'" >> cross_file.txt && \
    echo "ranlib = '${RANLIB}'" >> cross_file.txt && \
    echo "strip = '${STRIP}'" >> cross_file.txt && \
    echo "pkgconfig = '${PKG_CONFIG}'" >> cross_file.txt && \
    echo "" >> cross_file.txt && \
    echo "[host_machine]" >> cross_file.txt && \
    echo "system = 'linux'" >> cross_file.txt && \
    echo "cpu_family = '${ARCH}'" >> cross_file.txt && \
    echo "cpu = '${ARCH}'" >> cross_file.txt && \
    echo "endian = 'little'" >> cross_file.txt

ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release"

# iconv
WORKDIR /build/iconv
RUN ./configure --prefix=${PREFIX} --enable-extra-encodings --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libxml2
WORKDIR /build/libxml2
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    && make -j$(( $(nproc) / 4 )) && make install

# zlib
WORKDIR /build/zlib
RUN ./configure --prefix=${PREFIX} --static \
    && make -j$(( $(nproc) / 4 )) && make install

# fftw3
WORKDIR /build/fftw3
RUN ./bootstrap.sh --prefix=${PREFIX} --enable-static --disable-shared --enable-maintainer-mode --disable-fortran \
    --disable-doc --with-our-malloc --enable-threads --with-combined-threads --with-incoming-stack-boundary=2 \
    --enable-sse2 --enable-avx --enable-avx2 \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libfreetype
WORKDIR /build/freetype
RUN ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    && make -j$(( $(nproc) / 4 )) && make install

# fribidi
WORKDIR /build/fribidi
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    && make -j$(( $(nproc) / 4 )) && make install

ENV OLD_CFLAGS=${CFLAGS}
ENV OLD_CXXFLAGS=${CXXFLAGS}
ENV CFLAGS="${CFLAGS} -fno-strict-aliasing"
ENV CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"

# openssl
WORKDIR /build/openssl
RUN ./Configure threads zlib no-shared enable-camellia enable-ec enable-srp --prefix=${PREFIX} linux-x86_64 --libdir=${PREFIX}/lib \
    --cross-compile-prefix='' \
    && sed -i -e "/^CFLAGS=/s|=.*|=${CFLAGS}|" -e "/^LDFLAGS=/s|=[[:space:]]*$|=${LDFLAGS}|" Makefile \
    && make -j$(( $(nproc) / 4 )) build_sw && make install_sw

ENV CFLAGS=${OLD_CFLAGS}
ENV CXXFLAGS=${OLD_CXXFLAGS}

# fontconfig
WORKDIR /build/fontconfig
RUN ./autogen.sh --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared --sysconfdir=/etc --localstatedir=/var \
    && ./configure --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared --sysconfdir=/etc --localstatedir=/var \
    && make -j$(( $(nproc) / 4 )) && make install

# libpciaccess
WORKDIR /build/libpciaccess
RUN meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -j$(( $(nproc) / 4 )) -C build && ninja -C build install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libpciaccess.pc

# xcbproto
WORKDIR /build/xcbproto
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && mv ${PREFIX}/share/pkgconfig/xcb-proto.pc ${PREFIX}/lib/pkgconfig/xcb-proto.pc

# xproto
WORKDIR /build/xproto
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && mv ${PREFIX}/share/pkgconfig/xproto.pc ${PREFIX}/lib/pkgconfig/xproto.pc

# xtrans
WORKDIR /build/libxtrans
RUN ./autogen.sh --prefix=${PREFIX} --without-xmlto --without-fop --without-xsltproc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --without-xmlto --without-fop --without-xsltproc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && cp -r ${PREFIX}/share/aclocal/. ${PREFIX}/lib/aclocal

# libxcb
WORKDIR /build/libxcb
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-devel-docs \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-devel-docs \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libx11
WORKDIR /build/libx11
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --without-xmlto --without-fop --without-xsltproc --without-lint --disable-specs --enable-ipv6 \
    --host=${CROSS_PREFIX%-} \
    --disable-malloc0returnsnull \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --without-xmlto --without-fop --without-xsltproc --without-lint --disable-specs --enable-ipv6 \
    --host=${CROSS_PREFIX%-} \
    --disable-malloc0returnsnull \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/x11.pc

# libxfixes
WORKDIR /build/libxfixes
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/xfixes.pc

# libdrm
WORKDIR /build/libdrm
RUN mkdir build && cd build \
    && meson --prefix=${PREFIX} --buildtype=release \
    -Ddefault_library=static -Dudev=false -Dcairo-tests=disabled \
    -Dvalgrind=disabled -Dexynos=disabled -Dfreedreno=disabled \
    -Domap=disabled -Detnaviv=disabled -Dintel=enabled \
    -Dnouveau=enabled -Dradeon=enabled -Damdgpu=enabled \
    --cross-file=../../cross_file.txt .. \
    && ninja -j$(( $(nproc) / 4 )) && ninja install install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libdrm.pc

# harfbuzz
WORKDIR /build/harfbuzz
RUN meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -j$(( $(nproc) / 4 )) -C build && ninja -C build install

# libudfread
WORKDIR /build/libudfread
RUN ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(( $(nproc) / 4 )) && make install \
    && ln -s libudfread.pc ${PREFIX}/lib/pkgconfig/udfread.pc

# avisynth
WORKDIR /build/avisynth
RUN mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DHEADERS_ONLY=ON \
    && make -j$(( $(nproc) / 4 )) && make VersionGen install

# chromaprint
WORKDIR /build/chromaprint
RUN mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_TOOLS=OFF \
    -DBUILD_TESTS=OFF \
    -DFFT_LIB=fftw3 \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lfftw3 -lstdc++" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc \
    && echo "Cflags.private: -DCHROMAPRINT_NODLL" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc

# libass
WORKDIR /build/libass
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(( $(nproc) / 4 )) && make install

# libva
WORKDIR /build/libva
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-x11 --enable-drm --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-x11 --enable-drm --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libva.pc

# libgpg-error
WORKDIR /build/libgpg-error
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libgpg-error.pc

# libgcrypt
WORKDIR /build/libgcrypt
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libgcrypt.pc

RUN echo '#!/bin/sh' > /usr/local/bin/libgcrypt-config \
    && echo 'pkg-config libgcrypt "$@"' >> /usr/local/bin/libgcrypt-config \
    && chmod +x /usr/local/bin/libgcrypt-config

RUN echo '#!/bin/sh' > /usr/local/bin/gpg-error-config \
    && echo 'pkg-config libgpg-error "$@"' >> /usr/local/bin/gpg-error-config \
    && chmod +x /usr/local/bin/gpg-error-config

# libbdplus
WORKDIR /build/libbdplus
RUN ./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libbdplus.pc

# libaacs
WORKDIR /build/libaacs
RUN ./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libaacs.pc

# libbluray
WORKDIR /build/libbluray
RUN sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.c \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.h \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/disc.c

ENV EXTRA_LIBS="-L${PREFIX}/lib -laacs -lbdplus"

RUN export EXTRA_LIBS=${EXTRA_LIBS} \
    && ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -laacs -lbdplus -lstdc++" >> ${PREFIX}/lib/pkgconfig/libbluray.pc \
    && export EXTRA_LIBS=""

ENV EXTRA_LIBS=""

# rav1e
WORKDIR /build/rav1e
RUN cargo cinstall -v --prefix=${PREFIX} --library-type=staticlib --crt-static --release \
    && sed -i 's/-lgcc_s//' ${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/rav1e.pc \
    && cp ${PREFIX}/lib/x86_64-linux-gnu/pkgconfig/rav1e.pc ${PREFIX}/lib/pkgconfig/rav1e.pc

# libsrt
WORKDIR /build/libsrt
RUN mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DENABLE_CXX_DEPS=ON -DUSE_STATIC_LIBSTDCXX=ON -DENABLE_ENCRYPTION=ON -DENABLE_APPS=OFF \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/srt.pc

# twolame
WORKDIR /build/twolame
RUN NOCONFIGURE=1 ./autogen.sh \
    && touch doc/twolame.1 \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-sndfile \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && sed -i 's/Cflags:/Cflags: -DLIBTWOLAME_STATIC/' ${PREFIX}/lib/pkgconfig/twolame.pc

ENV CFLAGS="${CFLAGS} -DLIBTWOLAME_STATIC"

# mp3lame
WORKDIR /build/lame
RUN ./configure --prefix=${PREFIX} --enable-static --disable-shared --enable-nasm --disable-gtktest --disable-cpml --disable-frontend --disable-decoder \
    && make -j$(( $(nproc) / 4 )) && make install

# fdk-aac
WORKDIR /build/fdk-aac
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    && make -j$(( $(nproc) / 4 )) && make install

# opus
WORKDIR /build/opus
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    && make -j$(( $(nproc) / 4 )) && make install

# libvpx
WORKDIR /build/libvpx
RUN ./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    && make -j$(( $(nproc) / 4 )) && make install

# x264
WORKDIR /build/x264
RUN ./configure --prefix=${PREFIX} --disable-cli --enable-static --enable-pic --disable-shared --disable-lavf --disable-swscale \
    && make -j$(( $(nproc) / 4 )) && make install

# x265
# build x265 12bit
WORKDIR /build/x265
RUN rm -rf build/linux/12bit build/linux/10bit build/linux/8bit \
    && mkdir -p build/linux/12bit build/linux/10bit build/linux/8bit \
    && cd 12bit \
    && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 )) \
    # build x265 10bit
    && cd ../10bit \
    && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 )) \
    # build x265 8bit
    && cd ../8bit \
    && mv ../12bit/libx265.a ./libx265_main12.a && mv ../10bit/libx265.a ./libx265_main10.a \
    && cmake ${CMAKE_COMMON_ARG} -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 ))

# install x265
WORKDIR /build/x265/build/linux/8bit
RUN mv libx265.a libx265_main.a \
    && { \
    echo "CREATE libx265.a"; \
    echo "ADDLIB libx265_main.a"; \
    echo "ADDLIB libx265_main10.a"; \
    echo "ADDLIB libx265_main12.a"; \
    echo "SAVE"; \
    echo "END"; \
    } | ar -M \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc"

ENV OLD_CFLAGS=${CFLAGS}
ENV CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"

# xvid
WORKDIR /build/xvidcore/build/generic
RUN CFLAGS=${CFLAGS} \
    ./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \ 
    CC=${CC} \
    CXX=${CXX} \
    && make -j$(( $(nproc) / 4 )) && make install

ENV CFLAGS=${OLD_CFLAGS}

# libwebp
WORKDIR /build/libwebp
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    && make -j$(( $(nproc) / 4 )) && make install

# openjpeg
WORKDIR /build/openjpeg
RUN mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_PKGCONFIG_FILES=ON \
    -DBUILD_CODEC=OFF \
    -DWITH_ASTYLE=OFF \
    -DBUILD_TESTING=OFF \
    && make -j$(( $(nproc) / 4 )) && make install

# zimg
WORKDIR /build/zimg
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    && make -j$(( $(nproc) / 4 )) && make install

# ffnvcodec
WORKDIR /build/ffnvcodec
RUN make PREFIX=${PREFIX} install

# ffmpeg
WORKDIR /build/ffmpeg
RUN ./configure --pkg-config-flags=--static \
    --arch=${ARCH} \
    --target-os=linux \
    --cross-prefix=${CROSS_PREFIX} \
    --pkg-config=pkg-config \
    --prefix=${PREFIX} \
    --enable-cross-compile \
    --disable-shared \
    --enable-static \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --enable-iconv \
    --enable-libxml2 \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-fontconfig \
    --enable-libdrm \
    --enable-avisynth \
    --enable-chromaprint \
    --enable-libass \
    --enable-vaapi \
    --enable-libbluray \
    --enable-librav1e \
    --enable-libsrt \
    --enable-libtwolame \
    --enable-libmp3lame \
    --enable-libfdk-aac \
    --enable-libopus \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxvid \
    --enable-libwebp \
    --enable-libopenjpeg \
    --enable-libzimg \
    --enable-ffnvcodec \
    --enable-nvenc \
    # --enable-cuda-llvm \
    --enable-runtime-cpudetect \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I${PREFIX}/include" \
    --extra-ldflags="-static -static-libgcc -static-libstdc++ -L${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(( $(nproc) / 4 )) && make install

RUN mkdir -p /ffmpeg/linux

RUN cp ${PREFIX}/bin/ffmpeg /ffmpeg/linux
RUN cp ${PREFIX}/bin/ffprobe /ffmpeg/linux

RUN tar -czf /ffmpeg-linux-7.1.tar.gz -C /ffmpeg/linux .

# cleanup
RUN rm -rf /ffmpeg/linux ${PREFIX}

CMD ["/export.sh"]
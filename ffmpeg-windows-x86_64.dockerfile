# Create a Windows ffmpeg build
FROM nomercyentertainment/ffmpeg-base AS windows

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0.0"
LABEL description="FFmpeg for Windows x86_64"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    mingw-w64 libgit2-dev \
    && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rustup target add x86_64-pc-windows-gnu \
    && cargo install cargo-c

RUN cd /build

# Set environment variables for building ffmpeg
ENV PREFIX=/ffmpeg_build/windows
ENV ARCH=x86_64
ENV CROSS_PREFIX=${ARCH}-w64-mingw32-
ENV CC=${CROSS_PREFIX}gcc
ENV CXX=${CROSS_PREFIX}g++
ENV LD=${CROSS_PREFIX}ld
ENV AR=${CROSS_PREFIX}gcc-ar
ENV RANLIB=${CROSS_PREFIX}gcc-ranlib
ENV STRIP=${CROSS_PREFIX}strip
ENV NM=${CROSS_PREFIX}gcc-nm
ENV WINDRES=${CROSS_PREFIX}windres
ENV DLLTOOL=${CROSS_PREFIX}dlltool
ENV STAGE_CFLAGS="-fno-semantic-interposition" 
ENV STAGE_CXXFLAGS="-fno-semantic-interposition"
ENV PKG_CONFIG=pkg-config
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV PATH="${PREFIX}/bin:${PATH}"
ENV CFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong"
ENV CXXFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong"
ENV LDFLAGS="-static-libgcc -static-libstdc++ -L${PREFIX}/lib -O2 -pipe -fstack-protector-strong"

# Create the build directory
RUN mkdir -p ${PREFIX}

# Create Meson cross file for Windows
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
    echo "system = 'windows'" >> /build/cross_file.txt && \
    echo "cpu_family = '${ARCH}'" >> /build/cross_file.txt && \
    echo "cpu = '${ARCH}'" >> /build/cross_file.txt && \
    echo "endian = 'little'" >> /build/cross_file.txt

ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_RC_COMPILER=${WINDRES} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release"

# iconv
RUN cd /build/iconv \
    && ./configure --prefix=${PREFIX} --enable-extra-encodings --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/iconv \
    \
    # libxml2
    && cd /build/libxml2 \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
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
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/freetype \
    \
    # fribidi
    && cd /build/fribidi \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
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

ENV OLD_CFLAGS=${CFLAGS}
ENV OLD_CXXFLAGS=${CXXFLAGS}
ENV CFLAGS="${CFLAGS} -fno-strict-aliasing"
ENV CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"

# openssl
RUN cd /build/openssl \
    && ./Configure threads zlib no-shared enable-camellia enable-ec enable-srp --prefix=${PREFIX} mingw64 --libdir=${PREFIX}/lib \
    --cross-compile-prefix='' \
    && sed -i -e "/^CFLAGS=/s|=.*|=${CFLAGS}|" -e "/^LDFLAGS=/s|=[[:space:]]*$|=${LDFLAGS}|" Makefile \
    && make -j$(nproc) build_sw && make install_sw \
    && rm -rf /build/openssl

ENV CFLAGS=${OLD_CFLAGS}
ENV CXXFLAGS=${OLD_CXXFLAGS}

# fontconfig
RUN cd /build/fontconfig \
    && ./autogen.sh --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/fontconfig

# harfbuzz
RUN cd /build/harfbuzz \
    && meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -C build && ninja -C build install \
    && rm -rf /build/harfbuzz

# libudfread
RUN cd /build/libudfread \
    && ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
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
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libass

# libgpg-error
RUN cd /build/libgpg-error \
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
RUN cd /build/libcdio \
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
RUN cp -r /build/libdavs2/build/linux /build/libdavs2/build/windows \
    && cd /build/libdavs2/build/windows \
    && sed -i -e 's/EGIB/bss/g' -e 's/naidnePF/bss/g' configure \
    && ./configure --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libdavs2

# librav1e
RUN cd /build/librav1e \
    && cargo cinstall -v --prefix=${PREFIX} --library-type=staticlib --crt-static --release --target=x86_64-pc-windows-gnu \
    && sed -i 's/-lgcc_s//' ${PREFIX}/lib/pkgconfig/rav1e.pc \
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
    && autoreconf -i \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --enable-nasm --disable-gtktest --disable-cpml --disable-frontend --disable-decode \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/lame

# fdk-aac
RUN cd /build/fdk-aac \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(nproc) && make install \
    && rm -rf /build/fdk-aac

# opus
RUN cd /build/opus \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
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
    && CROSS=${CROSS_PREFIX} \
    DIST_DIR=${PREFIX} \
    ./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    --target=${ARCH}-win64-gcc \
    && make -j$(nproc) && make install \
    && rm -rf /build/libvpx

# x264
RUN cd /build/x264 \
    && ./configure \
    --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --disable-lavf --disable-swscale \
    --cross-prefix=${CROSS_PREFIX} --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(nproc) && make install \
    && rm -rf /build/x264

ENV CMAKE_X265_ARG="${CMAKE_COMMON_ARG} -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy"
# x265
# build x265 12bit
RUN cp -r /build/x265/build/linux /build/x265/build/windows \
    && cd /build/x265 \
    && rm -rf build/windows/12bit build/windows/10bit build/windows/8bit \
    && mkdir -p build/windows/12bit build/windows/10bit build/windows/8bit \
    && cd build/windows/12bit \
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
    } | ${AR} -M \
    && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc" \
    && rm -rf /build/x265

# xavs2
RUN cp -r /build/libxavs2/build/linux /build/libxavs2/build/windows \
    && cd /build/libxavs2/build/windows \
    && ./configure --prefix=${PREFIX} \
    --disable-cli --enable-static --enable-pic --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --disable-lsmash --extra-asflags="-w-macro-params-legacy" \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxavs2

ENV OLD_CFLAGS=${CFLAGS}
ENV CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"

# xvid
RUN cd /build/xvidcore \
    && cd build/generic \
    && sed -i 's/-mno-cygwin//g' Makefile \
    && sed -i 's/-mno-cygwin//g' configure \
    && CFLAGS=${CFLAGS} \
    ./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \ 
    CC=${CC} \
    CXX=${CXX} \
    && make -j$(nproc) && make install \
    && mv ${PREFIX}/lib/xvidcore.a ${PREFIX}/lib/libxvidcore.a \
    && mv ${PREFIX}/lib/xvidcore.dll.a ${PREFIX}/lib/libxvidcore.dll.a \
    && rm -rf /build/xvidcore

ENV CFLAGS=${OLD_CFLAGS}

# libwebp
RUN cd /build/libwebp \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libwebp \
    # fix libsharpyuv
    && cp ${PREFIX}/lib/pkgconfig/libsharpyuv.pc ${PREFIX}/lib/pkgconfig/sharpyuv.pc \
    \
    # openjpeg
    && cd /build/openjpeg \
    && mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_PKGCONFIG_FILES=ON \
    -DBUILD_CODEC=OFF \
    -DWITH_ASTYLE=OFF \
    -DBUILD_TESTING=OFF \
    && make -j$(nproc) && make install \
    && rm -rf /build/openjpeg \
    \
    # zimg
    && cd /build/zimg \
    &&  ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
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
    && mv amf/public/include ${PREFIX}/include/AMF \
    && rm -rf /build/amf

# Build libjpeg-turbo
RUN wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.0.2.tar.gz -O libjpeg-turbo-3.0.2.tar.gz \
    && tar xzf libjpeg-turbo-3.0.2.tar.gz \
    && cd libjpeg-turbo-3.0.2 \
    && mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libjpeg-turbo-3.0.2

# Build libtiff
RUN wget https://download.osgeo.org/libtiff/tiff-4.6.0.tar.gz \
    && tar xzf tiff-4.6.0.tar.gz \
    && cd tiff-4.6.0 \
    && ./configure --host=${CROSS_PREFIX%-} --prefix=${PREFIX} \
    --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && sed -i 's/^Libs: \(.*\)/Libs: \1 -lz/' ${PREFIX}/lib/pkgconfig/libtiff-4.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libtiff-4.pc && \
    rm -rf /build/tiff-4.6.0

# leptonica
RUN cd /build/leptonica \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --disable-programs \
    --without-giflib \
    --without-jpeg \
    --without-libopenjpeg \
    --without-libwebp \
    --without-libtiff \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --disable-programs \
    --without-giflib \
    --without-jpeg \
    --without-libopenjpeg \
    --without-libwebp \
    --without-libtiff \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && sed -i 's/^Libs: \(.*\)/Libs: \1 -lws2_32/' ${PREFIX}/lib/pkgconfig/lept.pc \
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
    && sed -i 's/^Libs: \(.*\)/Libs: \1 -lws2_32/' ${PREFIX}/lib/pkgconfig/tesseract.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/tesseract.pc \
    && cp ${PREFIX}/lib/pkgconfig/tesseract.pc ${PREFIX}/lib/pkgconfig/libtesseract.pc 

# libsamplerate
RUN git clone --branch 0.2.2 https://github.com/libsndfile/libsamplerate.git /build/libsamplerate \
    && mkdir -p /build/libsamplerate/build && cd /build/libsamplerate/build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DLIBSAMPLERATE_EXAMPLES=OFF -DLIBSAMPLERATE_INSTALL=ON \
    && make -j$(nproc) && make install \
    && rm -rf /build/libsamplerate && cd /build \
    \    
    # sdl2
    && cd /build/sdl2 \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_STATIC_PIC=ON \
    && make -j$(nproc) && make install \
    && sed -ri -e 's/\-Wl,\-\-no\-undefined.*//' -e 's/ \-mwindows//g' -e 's/ \-lSDL2main//g' -e 's/ \-Dmain=SDL_main//g' ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && sed -ri -e 's/ -lSDL2//g' -e 's/Libs: /Libs: -lSDL2 /' ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && echo 'Requires: samplerate' >> ${PREFIX}/lib/pkgconfig/sdl2.pc \
    && rm -rf /build/sdl2 && cd /build

# ffmpeg
RUN cd /build/ffmpeg \
    && ./configure --pkg-config-flags=--static \
    --arch=${ARCH} \
    --target-os=mingw32 \
    --cross-prefix=${CROSS_PREFIX} \
    --pkg-config=pkg-config \
    --prefix=${PREFIX} \
    --disable-shared \
    --enable-cross-compile \
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
    # --enable-libdrm \
    --enable-libvorbis \
    --enable-libvmaf \
    --enable-avisynth \
    --enable-chromaprint \
    --enable-libass \
    # --enable-vaapi \
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
    --enable-runtime-cpudetect \
    --cc=${CC} \
    --cxx=${CXX} \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I${PREFIX}/include" \
    --extra-ldflags="-static -static-libgcc -static-libstdc++ -L${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(nproc) && make install

RUN mkdir -p /ffmpeg/windows \
    && cp ${PREFIX}/bin/ffplay.exe /ffmpeg/windows \
    && cp ${PREFIX}/bin/ffmpeg.exe /ffmpeg/windows \
    && cp ${PREFIX}/bin/ffprobe.exe /ffmpeg/windows

# cleanup
RUN rm -rf ${PREFIX} /build

RUN mkdir -p /build/windows /output \
    && tar -czf /build/ffmpeg-windows-x86_64-7.1.tar.gz \
    -C /ffmpeg/windows . \
    && cp /build/ffmpeg-windows-x86_64-7.1.tar.gz /output

RUN apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cp /ffmpeg/windows /build/windows -r

FROM debian AS final

COPY --from=windows /build /build

CMD ["cp", "/build/ffmpeg-windows-x86_64-7.1.tar.gz", "/output"]
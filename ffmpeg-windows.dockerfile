# Create a Windows ffmpeg build
FROM nomercyffmpeg_ffmpeg-base AS windows

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0"
LABEL description="FFmpeg for Windows"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    mingw-w64 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

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
RUN echo "[binaries]" > cross_file.txt && \
    echo "c = '${CC}'" >> cross_file.txt && \
    echo "cpp = '${CXX}'" >> cross_file.txt && \
    echo "ar = '${AR}'" >> cross_file.txt && \
    echo "strip = '${STRIP}'" >> cross_file.txt && \
    echo "pkgconfig = '${PKG_CONFIG}'" >> cross_file.txt && \
    echo "" >> cross_file.txt && \
    echo "[host_machine]" >> cross_file.txt && \
    echo "system = 'windows'" >> cross_file.txt && \
    echo "cpu_family = '${ARCH}'" >> cross_file.txt && \
    echo "cpu = '${ARCH}'" >> cross_file.txt && \
    echo "endian = 'little'" >> cross_file.txt

ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_RC_COMPILER=${WINDRES} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF"

# iconv
WORKDIR /build/iconv
RUN ./configure --prefix=${PREFIX} --enable-extra-encodings --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libxml2
WORKDIR /build/libxml2
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
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
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# fribidi
WORKDIR /build/fribidi
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

ENV OLD_CFLAGS=${CFLAGS}
ENV OLD_CXXFLAGS=${CXXFLAGS}
ENV CFLAGS="${CFLAGS} -fno-strict-aliasing"
ENV CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"

# openssl
WORKDIR /build/openssl
RUN ./Configure threads zlib no-shared enable-camellia enable-ec enable-srp --prefix=${PREFIX} mingw64 --libdir=${PREFIX}/lib \
    --cross-compile-prefix='' \
    && sed -i -e "/^CFLAGS=/s|=.*|=${CFLAGS}|" -e "/^LDFLAGS=/s|=[[:space:]]*$|=${LDFLAGS}|" Makefile \
    && make -j$(( $(nproc) / 4 )) build_sw && make install_sw

ENV CFLAGS=${OLD_CFLAGS}
ENV CXXFLAGS=${OLD_CXXFLAGS}

# fontconfig
WORKDIR /build/fontconfig
RUN ./autogen.sh --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# harfbuzz
WORKDIR /build/harfbuzz
RUN meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -C build && ninja -C build install

# libudfread
WORKDIR /build/libudfread
RUN ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && ln -s libudfread.pc ${PREFIX}/lib/pkgconfig/udfread.pc

# avisynth
WORKDIR /build/avisynth
RUN mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DCMAKE_BUILD_TYPE=Release \
    -DHEADERS_ONLY=ON \
    && make -j$(( $(nproc) / 4 )) && make VersionGen install

# chromaprint
WORKDIR /build/chromaprint
RUN mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TOOLS=OFF \
    -DBUILD_TESTS=OFF \
    -DFFT_LIB=fftw3 \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lfftw3 -lstdc++" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc \
    && echo "Cflags.private: -DCHROMAPRINT_NODLL" >> ${PREFIX}/lib/pkgconfig/libchromaprint.pc

# libass
WORKDIR /build/libass
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libbdplus
WORKDIR /build/libbdplus
RUN ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libbluray
WORKDIR /build/libbluray
RUN sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.c \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.h \ 
    && sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/disc.c
RUN ./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-avisynth --enable-libaacs --enable-libbdplus \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-avisynth --enable-libaacs --enable-libbdplus \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

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
RUN autoreconf -i \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --enable-nasm --disable-gtktest --disable-cpml --disable-frontend --disable-decode \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# fdk-aac
WORKDIR /build/fdk-aac
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(( $(nproc) / 4 )) && make install

# opus
WORKDIR /build/opus
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# libvpx
WORKDIR /build/libvpx
RUN CROSS=${CROSS_PREFIX} \
    DIST_DIR=${PREFIX} \
    ./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    --target=${ARCH}-win64-gcc \
    && make -j$(( $(nproc) / 4 )) && make install

# x264
WORKDIR /build/x264
RUN ./configure \
    --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --disable-lavf --disable-swscale \
    --cross-prefix=${CROSS_PREFIX} --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(( $(nproc) / 4 )) && make install

# x265
RUN cp -r /build/x265/build/linux /build/x265/build/windows
# build x265 12bit
WORKDIR /build/x265/build/windows
RUN rm -rf 8bit 10bit 12bit && mkdir -p 8bit 10bit 12bit
RUN cd 12bit && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 ))

# build x265 10bit
WORKDIR /build/x265/build/windows
RUN cd 10bit && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 ))

# build x265 8bit
WORKDIR /build/x265/build/windows
RUN cd 8bit && mv ../12bit/libx265.a ./libx265_main12.a && mv ../10bit/libx265.a ./libx265_main10.a \
    && cmake ${CMAKE_COMMON_ARG} -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S ../../../source -B . \
    && make -j$(( $(nproc) / 4 ))

# install x265
WORKDIR /build/x265/build/windows/8bit
RUN mv libx265.a libx265_main.a \
    && { \
    echo "CREATE libx265.a"; \
    echo "ADDLIB libx265_main.a"; \
    echo "ADDLIB libx265_main10.a"; \
    echo "ADDLIB libx265_main12.a"; \
    echo "SAVE"; \
    echo "END"; \
    } | ${AR} -M \
    && make -j$(( $(nproc) / 4 )) && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc"

ENV OLD_CFLAGS=${CFLAGS}
ENV CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"

# xvid
WORKDIR /build/xvidcore/build/generic
RUN sed -i 's/-mno-cygwin//g' Makefile \
    && sed -i 's/-mno-cygwin//g' configure \
    && CFLAGS=${CFLAGS} \
    ./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \ 
    CC=${CC} \
    CXX=${CXX} \
    && make -j$(( $(nproc) / 4 )) && make install \
    && mv ${PREFIX}/lib/xvidcore.a ${PREFIX}/lib/libxvidcore.a \
    && mv ${PREFIX}/lib/xvidcore.dll.a ${PREFIX}/lib/libxvidcore.dll.a

ENV CFLAGS=${OLD_CFLAGS}

# libwebp
WORKDIR /build/libwebp
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# openjpeg
WORKDIR /build/openjpeg
RUN mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_PKGCONFIG_FILES=ON \
    -DBUILD_CODEC=OFF \
    -DWITH_ASTYLE=OFF \
    -DBUILD_TESTING=OFF \
    && make -j$(( $(nproc) / 4 )) && make install

# zimg
WORKDIR /build/zimg
RUN  ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(( $(nproc) / 4 )) && make install

# ffnvcodec
WORKDIR /build/ffnvcodec
RUN make PREFIX=${PREFIX} install

# ffmpeg
WORKDIR /build/ffmpeg
RUN ./configure --pkg-config-flags=--static \
    --arch=${ARCH} \
    --target-os=mingw32 \
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
    --enable-avisynth \
    --enable-chromaprint \
    --enable-libass \
    --enable-libbluray \
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
    # --enable-cuda-llvm \ --enable-libdbplus
    --enable-runtime-cpudetect \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I/${PREFIX}/include" \
    --extra-ldflags="-static -static-libgcc -static-libstdc++ -L/${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(( $(nproc) / 4 )) && make install

RUN mkdir -p /ffmpeg/windows

RUN cp ${PREFIX}/bin/ffmpeg.exe /ffmpeg/windows
RUN cp ${PREFIX}/bin/ffprobe.exe /ffmpeg/windows

RUN tar -czf /ffmpeg-windows-7.1.tar.gz -C /ffmpeg/windows .

# cleanup
RUN rm -rf /ffmpeg/windows ${PREFIX}

CMD ["/export.sh"]
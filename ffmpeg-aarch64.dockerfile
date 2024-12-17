# Create a Windows ffmpeg build
FROM stoney-ffmpeg-base AS aarch64

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0"
LABEL description="FFmpeg for Aarch64"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Set environment variables for building ffmpeg
ENV PREFIX=/ffmpeg_build/aarch64
ENV ARCH=aarch64
ENV CROSS_PREFIX=${ARCH}-linux-gnu-
ENV CC=${CROSS_PREFIX}gcc
ENV CXX=${CROSS_PREFIX}g++
ENV LD=${CROSS_PREFIX}ld
ENV AR=${CROSS_PREFIX}gcc-ar
ENV RANLIB=${CROSS_PREFIX}gcc-ranlib
ENV STRIP=${CROSS_PREFIX}strip
# ENV WINDRES=${CROSS_PREFIX}windres
ENV NM=${CROSS_PREFIX}gcc-nm
# ENV DLLTOOL=${CROSS_PREFIX}dlltool
ENV STAGE_CFLAGS="-fvisibility=hidden -fno-semantic-interposition" 
ENV STAGE_CXXFLAGS="-fvisibility=hidden -fno-semantic-interposition"
ENV PKG_CONFIG=pkg-config
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV PATH="${PREFIX}/bin:${PATH}"
ENV CFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread"
ENV CXXFLAGS="-static-libgcc -static-libstdc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -D_FORTIFY_SOURCE=2 -fstack-protector-strong -fstack-clash-protection -pthread"
ENV LDFLAGS="-static-libgcc -static-libstdc++ -L/opt/ffbuild/lib -O2 -pipe -fstack-protector-strong -fstack-clash-protection -Wl,-z,relro,-z,now -pthread -lm"
ENV LD_LIBRARY_PATH="/usr/local/lib:${PREFIX}/lib:$LD_LIBRARY_PATH"

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

# iconv
WORKDIR /build/iconv
RUN ./configure --prefix=${PREFIX} --enable-extra-encodings --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# zlib
WORKDIR /build/zlib
RUN ./configure --prefix=${PREFIX} --static \
    && make -j$(nproc) && make install

# libxml2
WORKDIR /build/libxml2
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --without-python --disable-maintainer-mode \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# zlib
WORKDIR /build/zlib
RUN ./configure --prefix=${PREFIX} --static \
    && make -j$(nproc) && make install

# libfreetype
WORKDIR /build/freetype
RUN ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# fribidi
WORKDIR /build/fribidi
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-bin --disable-docs --disable-tests \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# fontconfig
WORKDIR /build/fontconfig
RUN ./autogen.sh --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --disable-docs --enable-iconv --enable-libxml2 --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# harfbuzz
WORKDIR /build/harfbuzz
RUN meson build --prefix=${PREFIX} --buildtype=release -Ddefault_library=static \
    --cross-file=../cross_file.txt \
    && ninja -C build && ninja -C build install

# libass
WORKDIR /build/libass
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# mp3lame
WORKDIR /build/lame
RUN ./configure --prefix=${PREFIX} --enable-static --disable-shared --enable-nasm --disable-gtktest --disable-cpml --disable-frontend --disable-decode \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# libvpx
WORKDIR /build/libvpx
RUN CROSS=${CROSS_PREFIX} \
    DIST_DIR=${PREFIX} \
    ./configure \
    --disable-docs \
    --disable-examples \
    --disable-runtime-cpu-detect \
    --disable-shared \
    --disable-tools \
    --disable-unit-tests \
    --enable-avx \
    --enable-avx2 \
    --enable-avx512 \
    --enable-libyuv \
    --enable-mmx \
    --enable-pic \
    --enable-postproc \
    --enable-sse \
    --enable-sse2 \
    --enable-sse3 \
    --enable-sse4_1 \
    --enable-ssse3 \
    --enable-static \
    --enable-static-msvcrt \
    --enable-vp8 \
    --enable-vp9 \
    --enable-vp9-highbitdepth \
    --enable-vp9-postproc \
    --enable-vp9-temporal-denoising \
    --enable-webm_io \
    --prefix=${PREFIX} \
    --target=${ARCH}-win64-gcc \
    --as=yasm \
    && make -j$(nproc) && make install

# x264
WORKDIR /build/x264
RUN ./configure \
    --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --disable-lavf --disable-swscale \
    --cross-prefix=${CROSS_PREFIX} --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(nproc) && make install

# x265
ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_RC_COMPILER=${WINDRES} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF"

# build x265 12bit
WORKDIR /build/x265/build/linux
RUN rm -rf 8bit 10bit 12bit && mkdir -p 8bit 10bit 12bit
RUN cd 12bit && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -DMAIN12=ON -S ../../../source -B . \
    && make -j$(nproc)

# build x265 10bit
WORKDIR /build/x265/build/linux
RUN cd 10bit && cmake ${CMAKE_COMMON_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DENABLE_CLI=OFF -S ../../../source -B . \
    && make -j$(nproc)

# build x265 8bit
WORKDIR /build/x265/build/linux
RUN cd 8bit && mv ../12bit/libx265.a ./libx265_main12.a && mv ../10bit/libx265.a ./libx265_main10.a \
    && cmake ${CMAKE_COMMON_ARG} -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S ../../../source -B . \
    && make -j$(nproc)

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
    } | ${AR} -M \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc"

# xvid
WORKDIR /build/xvidcore/build/generic
RUN sed -i 's/-mno-cygwin//g' Makefile \
    && sed -i 's/-mno-cygwin//g' configure \
    && CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math" \
    ./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} \ 
    CC=${CC} \
    CXX=${CXX} \
    && make -j$(nproc) && make install \
    && mv ${PREFIX}/lib/xvidcore.a ${PREFIX}/lib/libxvidcore.a \
    && mv ${PREFIX}/lib/xvidcore.dll.a ${PREFIX}/lib/libxvidcore.dll.a

# fdk-aac
WORKDIR /build/fdk-aac
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-win64-gcc \
    && make -j$(nproc) && make install

# opus
WORKDIR /build/opus
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --disable-extra-programs \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

# libwebp
WORKDIR /build/libwebp
RUN ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --enable-libwebpmux --disable-libwebpextras --disable-libwebpdemux --disable-sdl --disable-gl --disable-png --disable-jpeg --disable-tiff --disable-gif \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

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
    && make -j$(nproc) && make install

# zimg
WORKDIR /build/zimg
RUN  ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install

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
    --enable-libass \
    --enable-libmp3lame \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxvid \
    --enable-libfdk-aac \
    --enable-libopus \
    --enable-libwebp \
    --enable-libopenjpeg \
    --enable-libzimg \
    --enable-ffnvcodec \
    # --enable-cuda-llvm \
    --enable-runtime-cpudetect \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-static -static-libgcc -static-libstdc++ -I/${PREFIX}/include" \
    --extra-ldflags="-static -static-libgcc -static-libstdc++ -L/${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(nproc) && make install

RUN mkdir -p /ffmpeg/aarch64

RUN cp ${PREFIX}/bin/ffmpeg.exe /ffmpeg/aarch64
RUN cp ${PREFIX}/bin/ffprobe.exe /ffmpeg/aarch64

RUN tar -czf /ffmpeg-aarch64-7.1.tar.gz -C /ffmpeg/aarch64 .
# cleanup
RUN rm -rf /build /ffmpeg_build

ADD start-aarch64.sh /start-aarch64.sh
RUN chmod 755 /start-aarch64.sh

# Set the entrypoint
CMD ["/start-aarch64.sh"]
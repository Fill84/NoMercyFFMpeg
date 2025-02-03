# Create a macOS ffmpeg build
FROM nomercyentertainment/ffmpeg-base AS darwin

LABEL maintainer="Phillippe Pelzer"
LABEL version="1.0.0"
LABEL description="FFmpeg for Darwin x86_64"

ENV DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,video

RUN apt-get update && apt-get install -y --no-install-recommends \
    clang patch liblzma-dev libxml2-dev xz-utils bzip2 cpio zlib1g-dev libgit2-dev \
    && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rustup target add x86_64-apple-darwin \
    && cargo install cargo-c

ENV PREFIX=/ffmpeg_build/darwin
ENV MACOSX_DEPLOYMENT_TARGET=10.13.0
ENV SDK_VERSION=15.1
ENV SDK_PATH=${PREFIX}/osxcross/SDK/MacOSX${SDK_VERSION}.sdk
ENV OSX_FRAMEWORKS=${SDK_PATH}/System/Library/Frameworks

RUN git clone https://github.com/tpoechtrager/osxcross.git /build/osxcross && cd /build/osxcross \
    && wget -nc https://github.com/joseluisq/macosx-sdks/releases/download/${SDK_VERSION}/MacOSX${SDK_VERSION}.sdk.tar.xz \
    && mv MacOSX${SDK_VERSION}.sdk.tar.xz tarballs/MacOSX${SDK_VERSION}.sdk.tar.xz \
    && git clone https://github.com/llvm/llvm-project.git /build/llvm-project \
    && mkdir -p ${SDK_PATH}/usr/include/c++/v1 \
    && cp -r /build/llvm-project/libcxx/include/* ${SDK_PATH}/usr/include/c++/v1/ \
    && cp -r /build/llvm-project/libcxxabi/include/* ${SDK_PATH}/usr/include/c++/v1/ \
    && UNATTENDED=1 SDK_VERSION=${SDK_VERSION} MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} TARGET_DIR=${PREFIX}/osxcross ./build.sh -Wno-dev

RUN echo "MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}" > ${PREFIX}/osxcross/bin/cc_target \
    && cp ${PREFIX}/osxcross/bin/cc_target ${SDK_PATH}/usr/bin/cc_target

RUN cd /build

# Set environment variables for building ffmpeg
ENV PREFIX=/ffmpeg_build/darwin
ENV ARCH=x86_64
ENV CROSS_PREFIX=${ARCH}-apple-darwin24.1-
ENV CC=${CROSS_PREFIX}clang
ENV CXX=${CROSS_PREFIX}clang++
ENV LD=${CROSS_PREFIX}ld
ENV AR=${CROSS_PREFIX}ar
ENV RANLIB=${CROSS_PREFIX}ranlib
ENV STRIP=${CROSS_PREFIX}strip
ENV NM=${CROSS_PREFIX}nm
# ENV WINDRES=${CROSS_PREFIX}windres
# ENV DLLTOOL=${CROSS_PREFIX}dlltool
ENV PKG_CONFIG=pkg-config
ENV PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
ENV PATH="${PREFIX}/bin:${SDK_PATH}/usr/bin:${PREFIX}/osxcross/bin:${PATH}"
ENV CFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDK_PATH} -F${OSX_FRAMEWORKS} -stdlib=libc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -pthread"
ENV CXXFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDK_PATH} -F${OSX_FRAMEWORKS} -stdlib=libc++ -I${PREFIX}/include -O2 -pipe -fPIC -DPIC -pthread"
ENV LDFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDK_PATH} -F${OSX_FRAMEWORKS} -stdlib=libc++ -L${PREFIX}/lib -Wl,-dead_strip_dylibs -pthread"

ENV CARGO_TARGET_X86_64_APPLE_DARWIN_LINKER=${CC}

# Create Meson cross file for darwin
RUN echo "[constants]" > /build/cross_file.txt && \
    echo "osx_sdk_version = '${MACOSX_DEPLOYMENT_TARGET}'" >> /build/cross_file.txt && \
    echo "osx_arch = '${ARCH}'" >> /build/cross_file.txt && \
    echo "" >> /build/cross_file.txt && \
    echo "[binaries]" >> /build/cross_file.txt && \
    echo "c = '${CC}'" >> /build/cross_file.txt && \
    echo "cpp = '${CXX}'" >> /build/cross_file.txt && \
    echo "ld = '${LD}'" >> /build/cross_file.txt && \
    echo "ar = '${AR}'" >> /build/cross_file.txt && \
    echo "ranlib = '${RANLIB}'" >> /build/cross_file.txt && \
    echo "strip = '${STRIP}'" >> /build/cross_file.txt && \
    echo "pkgconfig = '${PKG_CONFIG}'" >> /build/cross_file.txt && \
    echo "" >> /build/cross_file.txt && \
    echo "[host_machine]" >> /build/cross_file.txt && \
    echo "system = 'darwin'" >> /build/cross_file.txt && \
    echo "cpu_family = '${ARCH}'" >> /build/cross_file.txt && \
    echo "cpu = '${ARCH}'" >> /build/cross_file.txt && \
    echo "endian = 'little'" >> /build/cross_file.txt && \
    echo "" >> /build/cross_file.txt && \
    echo "[properties]" >> /build/cross_file.txt && \
    echo "c_args = ['-arch', '${ARCH}', '-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}', '-isysroot', '${SDK_PATH}', '-F${OSX_FRAMEWORKS}', '-stdlib=libc++', '-I${PREFIX}/include', '-O2', '-pipe', '-fPIC', '-DPIC', '-pthread']" >> /build/cross_file.txt && \
    echo "cpp_args = ['-arch', '${ARCH}', '-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}', '-isysroot', '${SDK_PATH}', '-F${OSX_FRAMEWORKS}', '-stdlib=libc++', '-I${PREFIX}/include', '-O2', '-pipe', '-fPIC', '-DPIC', '-pthread']" >> /build/cross_file.txt && \
    echo "c_link_args = ['-arch', '${ARCH}', '-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}', '-isysroot', '${SDK_PATH}', '-F${OSX_FRAMEWORKS}', '-stdlib=libc++', '-L${PREFIX}/lib', '-Wl,-dead_strip_dylibs', '-pthread']" >> /build/cross_file.txt && \
    echo "cpp_link_args = ['-arch', '${ARCH}', '-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}', '-isysroot', '${SDK_PATH}', '-F${OSX_FRAMEWORKS}', '-stdlib=libc++', '-L${PREFIX}/lib', '-Wl,-dead_strip_dylibs', '-pthread']" >> /build/cross_file.txt

# CMake common arguments for static build
ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -DCMAKE_OSX_SYSROOT=${SDK_PATH} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release"

RUN ln -s ${PREFIX}/osxcross/bin/${CROSS_PREFIX}install_name_tool ${SDK_PATH}/usr/bin/${CROSS_PREFIX}install_name_tool \
    && chmod +x ${SDK_PATH}/usr/bin/${CROSS_PREFIX}install_name_tool \
    && ln -s ${PREFIX}/osxcross/bin/${CROSS_PREFIX}otool ${SDK_PATH}/usr/bin/${CROSS_PREFIX}otool \
    && chmod +x ${SDK_PATH}/usr/bin/${CROSS_PREFIX}otool \
    && ln -s /build/osxcross/build/apple-libtapi/build/tools/llvm-objdump ${SDK_PATH}/usr/bin/${CROSS_PREFIX}objdump \
    && chmod +x ${SDK_PATH}/usr/bin/${CROSS_PREFIX}objdump \
    && ln -s /build/osxcross/build/apple-libtapi/build/tools/llvm-objcopy ${SDK_PATH}/usr/bin/${CROSS_PREFIX}objcopy \
    && chmod +x ${SDK_PATH}/usr/bin/${CROSS_PREFIX}objcopy \
    && ln -s ${CROSS_PREFIX}libtool /usr/bin/libtool

RUN mkdir -p /System/Library/Frameworks \
    && ln -s ${OSX_FRAMEWORKS}/System/Library/Frameworks /System/Library/Frameworks

ENV INSTALL_NAME_TOOL=${SDK_PATH}/usr/bin/${CROSS_PREFIX}install_name_tool
ENV OBJDUMP=${SDK_PATH}/usr/bin/${CROSS_PREFIX}objdump
ENV OBJCOPY=${SDK_PATH}/usr/bin/${CROSS_PREFIX}objcopy
ENV OTOOL=${SDK_PATH}/usr/bin/${CROSS_PREFIX}otool

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
    && ./configure --prefix=${PREFIX} --static --archs="-arch ${ARCH}" \
    && make -j$(nproc) && make install \
    && rm -rf /build/zlib \
    \
    # fftw3
    && cd /build/fftw3 \
    && ./bootstrap.sh \
    --prefix=${PREFIX} --enable-static --disable-shared --enable-maintainer-mode --disable-fortran \
    --disable-doc --with-our-malloc --enable-threads --with-combined-threads --with-incoming-stack-boundary=2 \
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
    && ./Configure threads zlib no-shared enable-camellia enable-ec enable-srp --prefix=${PREFIX} darwin64-${ARCH}-cc --libdir=${PREFIX}/lib \
    --cross-compile-prefix='' \
    && sed -i -e "/^CFLAGS=/s|=.*|=${CFLAGS}|" -e "/^LDFLAGS=/s|=[[:space:]]*$|=${LDFLAGS}|" Makefile \
    && make -j$(nproc) build_sw && make install_sw

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
    && mkdir -p /build/harfbuzz/src/unicode \
    && cp -r /usr/include/unicode/* /build/harfbuzz/src/unicode \
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
    && cp src/syscfg/lock-obj-pub.${ARCH}-apple-darwin.h src/syscfg/lock-obj-pub.${CROSS_PREFIX%-}.h \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc  \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && ln -s ${PREFIX}/lib/pkgconfig/gpg-error.pc ${PREFIX}/lib/pkgconfig/libgpg-error.pc \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libgpg-error.pc \
    && rm -rf /build/libgpg-error \
    \
    # libgcrypt
    && cd /build/libgcrypt \
    && ./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc --disable-asm --disable-test \
    --host=${CROSS_PREFIX%-} --target=${CROSS_PREFIX} --libdir=${PREFIX}/lib \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc --disable-asm --disable-test \
    --host=${CROSS_PREFIX%-} --target=${CROSS_PREFIX} --libdir=${PREFIX}/lib \
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
RUN cp -r /build/libdavs2/build/linux /build/libdavs2/build/darwin \
    && cd /build/libdavs2/build/darwin \
    # && sed -i -e 's/EGIB/bss/g' -e 's/naidnePF/bss/g' configure \
    && ./configure --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --with-pic --disable-asm \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libdavs2

# librav1e
RUN cd /build/librav1e \
    && cargo cinstall -v --prefix=${PREFIX} --library-type=staticlib --crt-static --release --target=${ARCH}-apple-darwin \
    && sed -i.backup 's/-lgcc_s/-lgcc_eh/g' ${PREFIX}/lib/pkgconfig/rav1e.pc \
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
    --host=${CROSS_PREFIX%-} --target=${ARCH}-apple-darwin \
    && ./configure --prefix=${PREFIX} --enable-static --disable-shared \
    --host=${CROSS_PREFIX%-} --target=${ARCH}-apple-darwin \
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

# CPUInfo (needed for SVT-AV1)
RUN git clone https://github.com/pytorch/cpuinfo.git /build/cpuinfo \
    && cd /build/cpuinfo \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -Wno-dev\
    && make -j$(nproc) && make install \
    \
    # libsvtav1
    && cd /build/libsvtav1 \
    && mkdir -p build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    -DBUILD_APPS=OFF -DBUILD_EXAMPLES=OFF -DENABLE_AVX512=ON \
    -DCPUINFO_ARCHITECTURE=${ARCH} \
    -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -Wno-dev \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++ -lcpuinfo" >> ${PREFIX}/lib/pkgconfig/svt-av1.pc \
    && rm -rf /build/libsvtav1

# libvpx
RUN cd /build/libvpx \
    && CROSS=${CROSS_PREFIX} \
    DIST_DIR=${PREFIX} \
    ./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
    --target=${ARCH}-darwin14-gcc \
    && make -j$(nproc) && make install \
    && rm -rf /build/libvpx

# x264
RUN cd /build/x264 \
    && ./configure \
    --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --disable-lavf --disable-swscale \
    --cross-prefix=${CROSS_PREFIX} --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/x264

ENV CMAKE_X265_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_OSX_SYSROOT=${SDK_PATH} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=OFF -DENABLE_CLI=OFF -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy"
# x265
# build x265 12bit
RUN cp -r /build/x265/build/linux /build/x265/build/windows \
    && cd /build/x265 \
    && rm -rf build/windows/12bit build/windows/10bit build/windows/8bit \
    && mkdir -p build/windows/12bit build/windows/10bit build/windows/8bit \
    && cd build/windows/12bit \
    && cmake ${CMAKE_X265_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -DMAIN12=ON -S ../../../source -B . \
    && make -j$(nproc) \
    # build x265 10bit
    && cd ../10bit \
    && cmake ${CMAKE_X265_ARG} -DHIGH_BIT_DEPTH=ON -DENABLE_HDR10_PLUS=ON -DEXPORT_C_API=OFF -S ../../../source -B . \
    && make -j$(nproc) \
    # build x265 8bit
    && cd ../8bit \
    && mv ../12bit/libx265.a ./libx265_main12.a && mv ../10bit/libx265.a ./libx265_main10.a \
    && cmake ${CMAKE_X265_ARG} -DEXTRA_LIB="x265_main10.a;x265_main12.a" -DEXTRA_LINK_FLAGS=-L. -DLINKED_10BIT=ON -DLINKED_12BIT=ON -S ../../../source -B . \
    && make -j$(nproc) \
    # install x265
    && mv libx265.a libx265_main.a \
    && ${CROSS_PREFIX}libtool -static -o libx265.a libx265_main.a libx265_main10.a libx265_main12.a \
    && ${RANLIB} libx265.a \
    && make install \
    && echo "Libs.private: -lstdc++" >> "${PREFIX}/lib/pkgconfig/x265.pc" \
    && rm -rf /build/x265

# xavs2
RUN cp -r /build/libxavs2/build/linux /build/libxavs2/build/darwin \
    && cd /build/libxavs2/build/darwin \
    && ./configure --prefix=${PREFIX} \
    --disable-cli --enable-static --enable-pic --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --disable-lsmash --extra-asflags="-w-macro-params-legacy" \
    --extra-cflags="-Wno-dev -Wno-typedef-redefinition -Wno-unused-but-set-variable -Wno-tautological-compare -Wno-format -Wno-incompatible-function-pointer-types" \
    --host=${CROSS_PREFIX%-} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libxavs2

ENV OLD_CFLAGS=${CFLAGS}
ENV CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"

# xvid
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

# # libvpl
# RUN cd /build/libvpl \
#     && mkdir -p build && cd build \
#     && cmake -GNinja -S .. -B . \
#     ${CMAKE_COMMON_ARG} \
#     -DCMAKE_INSTALL_BINDIR=${PREFIX}/bin -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib \
#     -DBUILD_DISPATCHER=ON -DBUILD_DEV=ON \
#     -DBUILD_PREVIEW=OFF -DBUILD_TOOLS=OFF -DBUILD_TOOLS_ONEVPL_EXPERIMENTAL=OFF -DINSTALL_EXAMPLE_CODE=OFF \
#     -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF \
#     && ninja -j$(nproc) && ninja install \
#     && rm -rf /build/libvpl ${PREFIX}/{etc,share}

# amf
RUN cd /build/amf \
    && mv amf/public/include ${PREFIX}/include/AMF

ENV OLD_CMAKE_COMMON_ARG=${CMAKE_COMMON_ARG}
ENV CMAKE_COMMON_ARG="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_OSX_ARCHITECTURES=${ARCH} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} -DCMAKE_OSX_SYSROOT=${SDK_PATH} -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DENABLE_SHARED=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_PROCESSOR=${ARCH} -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy"
# Build libjpeg-turbo
RUN wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.1.0.tar.gz -O libjpeg-turbo-3.1.0.tar.gz \
    && tar xzf libjpeg-turbo-3.1.0.tar.gz \
    && cd libjpeg-turbo-3.1.0 \
    && mkdir build && cd build \
    && cmake -S .. -B . \
    ${CMAKE_COMMON_ARG} \
    && make -j$(nproc) && make install \
    && rm -rf /build/libjpeg-turbo-3.1.0
ENV CMAKE_COMMON_ARG=${OLD_CMAKE_COMMON_ARG}

# Build libtiff
RUN wget https://download.osgeo.org/libtiff/tiff-4.6.0.tar.gz \
    && tar xzf tiff-4.6.0.tar.gz \
    && cd tiff-4.6.0 \
    && ./configure --host=${CROSS_PREFIX%-} --prefix=${PREFIX} \
    --enable-static --disable-shared \
    && make -j$(nproc) && make install \
    && echo "Libs.private: -lstdc++" >> ${PREFIX}/lib/pkgconfig/libtiff-4.pc && \
    rm -rf /build/tiff-4.6.0

# leptonica
RUN cd /build/leptonica \
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
    && sed -i '/#include <filesystem>/d' src/ccutil/ccutil.cpp \
    && sed -i 's/#include <cstring>/#include <cstring> \n#include <sys\/stat.h> \n#include <unistd.h>/' src/ccutil/ccutil.cpp \
    && sed -i 's/if (tessdata_prefix != nullptr && !std::filesystem::exists(tessdata_prefix)) {/struct stat buffer;\n    if (tessdata_prefix != nullptr \&\& stat(tessdata_prefix, \&buffer) != 0) {/' src/ccutil/ccutil.cpp \
    && sed -i 's/std::filesystem::exists(subdir)/stat(subdir.c_str(), \&buffer) == 0/' src/ccutil/ccutil.cpp \
    && sed -i 's/std::filesystem::path subdir = std::filesystem::path(path) \/ "tessdata";/std::string subdir = std::string(path) + "\\\\tessdata";/' src/ccutil/ccutil.cpp \
    && sed -i -e '/#include <filesystem>/d' \
    -e 's/#include <memory>/#include <memory>\n#include <dirent.h>\n#include <sys\/stat.h>/' \
    -e '/void addAvailableLanguages(const std::string \&datadir,/,/^}/c\\n void addAvailableLanguages(const std::string \&datadir, std::vector<std::string> *langs) {\n  DIR *dir = opendir(datadir.c_str());\n  if (!dir) return;\n\n  struct dirent *entry;\n  while ((entry = readdir(dir)) != nullptr) {\n    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;\n\n    std::string fullpath = datadir + "/" + entry->d_name;\n    struct stat statbuf;\n    if (stat(fullpath.c_str(), \&statbuf) != 0) continue;\n\n    if (S_ISDIR(statbuf.st_mode)) {\n      addAvailableLanguages(fullpath, langs);\n    } else {\n      std::string name = entry->d_name;\n      size_t pos = name.rfind(".traineddata");\n      if (pos != std::string::npos && pos == name.length() - 12) {\n        langs->push_back(name.substr(0, pos));\n      }\n    }\n  }\n  closedir(dir);\n}' src/api/baseapi.cpp \
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
    && echo "Libs.private: -lstdc++ -lz -framework Accelerate" >> ${PREFIX}/lib/pkgconfig/tesseract.pc \
    && cp ${PREFIX}/lib/pkgconfig/tesseract.pc ${PREFIX}/lib/pkgconfig/libtesseract.pc \
    && rm -rf /build/libtesseract

# # libsamplerate
# RUN git clone --branch 0.2.2 https://github.com/libsndfile/libsamplerate.git /build/libsamplerate \
#     && mkdir -p /build/libsamplerate/build && cd /build/libsamplerate/build \
#     && cmake -S .. -B . \
#     ${CMAKE_COMMON_ARG} \
#     -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DLIBSAMPLERATE_EXAMPLES=OFF -DLIBSAMPLERATE_INSTALL=ON \
#     && make -j$(nproc) && make install \
#     && rm -rf /build/libsamplerate && cd /build \
#     \    
#     # sdl2
#     && cd /build/sdl2 \
#     && mkdir -p build && cd build \
#     && cmake -GNinja -S .. -B . \
#     ${CMAKE_COMMON_ARG} \
#     -DSDL_SHARED=OFF \
#     -DSDL_STATIC=ON \
#     -DSDL_STATIC_PIC=ON \
#     -DSDL_TEST=OFF \
#     -DSDL_VIDEO=ON \
#     -DCMAKE_C_STANDARD=17 \
#     -DCMAKE_C_FLAGS="-std=c17" \
#     && ninja -j$(nproc) && ninja install \
#     && sed -ri -e 's/\-Wl,\-\-no\-undefined.*//' -e 's/ \-l\/.+?\.a//g' ${PREFIX}/lib/pkgconfig/sdl2.pc \
#     && sed -ri -e 's/ -lSDL2//g' -e 's/Libs: /Libs: -lSDL2 /' ${PREFIX}/lib/pkgconfig/sdl2.pc \
#     && echo 'Requires: samplerate' >> ${PREFIX}/lib/pkgconfig/sdl2.pc \
#     && rm -rf /build/sdl2 && cd /build

# ffmpeg
RUN cd /build/ffmpeg \
    && ./configure --pkg-config-flags=--static \
    --arch=${ARCH} \
    --target-os=darwin \
    --cross-prefix=${CROSS_PREFIX} \
    --pkg-config=pkg-config \
    --prefix=${PREFIX} \
    --disable-shared \
    --disable-videotoolbox \
    --enable-cross-compile \
    # --enable-ffplay \
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
    # --enable-libvpl \
    --enable-amf \
    # --enable-ffnvcodec \
    # --enable-nvdec \
    # --enable-nvenc \
    # --enable-cuda \
    # --enable-cuda-nvcc \
    # --enable-cuvid \
    # --enable-sdl2 \
    --enable-runtime-cpudetect \
    --cc=${CC} \
    --cxx=${CXX} \
    --extra-version="NoMercy-MediaServer" \
    --extra-cflags="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDK_PATH} -F${OSX_FRAMEWORKS} -stdlib=libc++ -isysroot ${SDK_PATH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -I${PREFIX}/include" \
    --extra-ldflags="-arch ${ARCH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -isysroot ${SDK_PATH} -F${OSX_FRAMEWORKS} -stdlib=libc++ -isysroot ${SDK_PATH} -mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET} -L${PREFIX}/lib" \
    --extra-libs="-lpthread -lm" \
    || (cat ffbuild/config.log ; false) && \
    make -j$(nproc) && make install

RUN mkdir -p /ffmpeg/darwin/${ARCH} \
    # && cp ${PREFIX}/bin/ffplay /ffmpeg/darwin/${ARCH} \
    && cp ${PREFIX}/bin/ffmpeg /ffmpeg/darwin/${ARCH} \
    && cp ${PREFIX}/bin/ffprobe /ffmpeg/darwin/${ARCH}

# cleanup
RUN rm -rf ${PREFIX} /build

RUN mkdir -p /output \
    && tar -czf /build/ffmpeg-7.1-darwin-${ARCH}.tar.gz \
    -C /ffmpeg/darwin/${ARCH} . \
    && cp /build/ffmpeg-7.1-darwin-${ARCH}.tar.gz /output

RUN apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cp /ffmpeg/darwin/${ARCH} /build/darwin -r

FROM debian AS final

COPY --from=darwin /build /build

CMD ["cp", "/build/ffmpeg-7.1-darwin-x86_64.tar.gz", "/output"]
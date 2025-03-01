#!/bin/bash

if [ ! -d ${PREFIX}/lib/pkgconfig ]; then
    mkdir -p ${PREFIX}/lib/pkgconfig
fi

# #region libpng
cd /build/libpng

./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pkgconfigdir=${PREFIX}/lib/pkgconfig \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pkgconfigdir=${PREFIX}/lib/pkgconfig \
    CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" \
    LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -lz" \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Failed to build libpng config" >>/ffmpeg_build.log
    exit 1
fi

make clean
make -j$(nproc)
make install

if [ ! -f ${PREFIX}/lib/libpng.a ]; then
    echo "Failed to build libpng a " >>/ffmpeg_build.log
    exit 1
fi
if [ ! -f ${PREFIX}/include/png.h ]; then
    echo "Failed to build libpng h " >>/ffmpeg_build.log
    exit 1
fi
if [ ! -f ${PREFIX}/include/pngconf.h ]; then
    echo "Failed to build libpng c" >>/ffmpeg_build.log
    exit 1
fi
if [ ! -f ${PREFIX}/include/pnglibconf.h ]; then
    echo "Failed to build libpng ch" >>/ffmpeg_build.log
    exit 1
fi
if [ ! -f ${PREFIX}/lib/pkgconfig/libpng.pc ]; then
    echo "Failed to build libpng p" >>/ffmpeg_build.log
    exit 1
fi
if [[ ${TARGET_OS} != "linux" ]]; then
    echo "Libs.private: -lstdc++ -lz" >>${PREFIX}/lib/pkgconfig/libpng.pc
else
    echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libpng.pc
fi
cd /build
rm -rf /build/libpng
if pkg-config --modversion libpng >/dev/null 2>&1; then
    echo "libpng is installed." >>/ffmpeg_build.log
else
    echo "libpng is missing!" >>/ffmpeg_build.log
    exit 1 # Optional: Exit script if libpng is not found
fi
# #endregion

#region libgif
cd /build/giflib
make -j$(nproc) && make install
if [ ! -f ${PREFIX}/include/gif_lib.h ]; then
    if [ -f gif_lib.h ]; then
        cp gif_lib.h ${PREFIX}/include/gif_lib.h
    else
        echo "Failed to build giflib 1" >>/ffmpeg_build.log
        exit 1
    fi
fi
if [ ! -f ${PREFIX}/lib/libgif.a ]; then
    if [ -f libgif.a ]; then
        cp libgif.a ${PREFIX}/lib/libgif.a
    else
        echo "Failed to build giflib 2" >>/ffmpeg_build.log
        exit 1
    fi
fi
if [ ! -f ${PREFIX}/lib/pkgconfig/giflib.pc ]; then
    if [ -f giflib.pc ]; then
        cp giflib.pc ${PREFIX}/lib/pkgconfig/giflib.pc
    else
        {
            echo "prefix=${PREFIX}"
            echo "exec_prefix=\${prefix}"
            echo "libdir=\${exec_prefix}/lib"
            echo "includedir=\${prefix}/include"
            echo ""
            echo "Name: giflib"
            echo "Description: GIF library"
            echo "Version: 5.2.2"
            echo "Libs: -L\${libdir} -lgif"
            echo "Cflags: -I\${includedir}"
        } >${PREFIX}/lib/pkgconfig/giflib.pc
    fi
fi
if [ ! -f ${PREFIX}/lib/pkgconfig/giflib.pc ]; then
    echo "Failed to build giflib 3" >>/ffmpeg_build.log
    exit 1
fi
if [[ ${TARGET_OS} != "linux" ]]; then
    echo "Libs.private: -lstdc++ -lz" >>${PREFIX}/lib/pkgconfig/giflib.pc
else
    echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/giflib.pc
fi
cd /build
rm -rf /build/giflib
#endregion

#region libtiff
cd /build/libtiff
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pkgconfigdir=${PREFIX}/lib/pkgconfig \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pkgconfigdir=${PREFIX}/lib/pkgconfig \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Failed to build libtiff" >>/ffmpeg_build.log
    exit 1
fi
make -j$(nproc) && make install
if [ ! -f ${PREFIX}/lib/pkgconfig/libtiff-4.pc ]; then
    echo "Failed to build libtiff" >>/ffmpeg_build.log
    exit 1
fi
if [[ ${TARGET_OS} != "linux" ]]; then
    echo "Libs.private: -lstdc++ -lz" >>${PREFIX}/lib/pkgconfig/libtiff-4.pc
else
    echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libtiff-4.pc
fi
cd /build
rm -rf /build/libtiff
#endregion

#region libwebp
cd /build/libwebp
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --enable-gif --enable-jpeg --enable-tiff \
    --with-pngincludedir=${PREFIX}/include --with-pnglibdir=${PREFIX}/lib --enable-png \
    LDFLAGS="${LDFLAGS} -L${PREFIX}/lib" \
    CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" \
    CFLAGS="${CFLAGS} -I${PREFIX}/include" \
    LIBS="-lpng16 -lz" \
    PNG_INCLUDES="I${PREFIX}/include" \
    PNG_LIBS="${PREFIX}/lib" \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --enable-libwebpmux --enable-libwebpextras --enable-libwebpdemux --enable-libwebpdecoder \
    --disable-sdl --disable-gl --enable-gif --enable-jpeg --enable-tiff \
    --with-pngincludedir=${PREFIX}/include --with-pnglibdir=${PREFIX}/lib --enable-png \
    LDFLAGS="${LDFLAGS} -L${PREFIX}/lib" \
    CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include" \
    CFLAGS="${CFLAGS} -I${PREFIX}/include" \
    LIBS="-lpng16 -lz" \
    PNG_INCLUDES="${PREFIX}/include" \
    PNG_LIBS="${PREFIX}/lib" \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Failed to build libwebp" >>/ffmpeg_build.log
    exit 1
fi

make -j$(nproc) && make install
rm -rf /build/libwebp

cp ${PREFIX}/lib/pkgconfig/libsharpyuv.pc ${PREFIX}/lib/pkgconfig/sharpyuv.pc
#endregion

add_enable "--enable-libwebp"

exit 0

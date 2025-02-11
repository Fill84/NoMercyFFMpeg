#!/bin/bash

if [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "linux" ]]; then
    cd /build/libcddb
    ./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
        --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        exit 1
    fi

    make -j$(nproc) && make install
    echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libcddb.pc
    rm -rf /build/libcddb
fi

cd /build/libcdio
touch src/cd-drive.1 src/cd-info.1 src/cd-read.1 src/iso-info.1 src/iso-read.1
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libcdio.pc
rm -rf /build/libcdio

# libcdio-paranoia
cd /build/libcdio-paranoia
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libcdio_paranoia.pc
rm -rf /build/libcdio-paranoia

add_enable "--enable-libcdio"

exit 0

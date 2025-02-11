#!/bin/bash

CONFIG="--host=${CROSS_PREFIX%-}"

if [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "linux" ]]; then
    CONFIG=""
fi

cd /build/libass
./autogen.sh --prefix="${PREFIX}" --enable-static --disable-shared --with-pic ${CONFIG}
./configure --prefix="${PREFIX}" --enable-static --disable-shared --with-pic ${CONFIG} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
rm -rf /build/libass

if [ ! -f "${PREFIX}/lib/pkgconfig/libass.pc" ]; then
    echo "libass failed to build" >>/ffmpeg_build.log
    exit 1
fi

add_enable "--enable-libass"

exit 0

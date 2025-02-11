#!/bin/bash

export OLD_CFLAGS=${CFLAGS}
export CFLAGS="${CFLAGS} -fstrength-reduce -ffast-math"
cd /build/xvidcore
cd build/generic
if [[ ${TARGET_OS} == "windows" ]]; then
    sed -i 's/-mno-cygwin//g' Makefile
    sed -i 's/-mno-cygwin//g' configure
fi
export CFLAGS=${CFLAGS}
./configure --enable-static --disable-shared \
    --prefix=${PREFIX} \
    --libdir=${PREFIX}/lib \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
if [[ ${TARGET_OS} == "windows" ]]; then
    mv ${PREFIX}/lib/xvidcore.a ${PREFIX}/lib/libxvidcore.a
    mv ${PREFIX}/lib/xvidcore.dll.a ${PREFIX}/lib/libxvidcore.dll.a
fi
rm -rf /build/xvidcore
export CFLAGS=${OLD_CFLAGS}

add_enable "--enable-libxvid"

exit 0

#!/bin/bash

cd /build/libudfread
./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
ln -s libudfread.pc ${PREFIX}/lib/pkgconfig/udfread.pc
rm -rf /build/libudfread

exit 0

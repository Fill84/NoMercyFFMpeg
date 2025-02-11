#!/bin/bash

EXTRA_CONFIG="--enable-x11 --enable-drm"
if [[ ${TARGET_OS} == "darwin" ]]; then
    exit 255
elif [[ ${TARGET_OS} == "windows" ]]; then
    EXTRA_CONFIG="--disable-x11 --disable-drm"
fi

cd /build/libva
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    ${EXTRA_CONFIG} --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic \
    ${EXTRA_CONFIG} --disable-docs --disable-glx --disable-wayland \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libva.pc
rm -rf /build/libva

add_enable "--enable-vaapi"

exit 0

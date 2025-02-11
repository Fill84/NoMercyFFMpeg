#!/bin/bash

CONF_FLAGS=""
if [[ ${TARGET} == "windows" ]]; then
    cp -r /build/libxavs2/build/linux /build/libxavs2/build/windows
    cd /build/libxavs2/build/windows
elif [[ ${TARGET} == "darwin" ]]; then
    cp -r /build/libxavs2/build/linux /build/libxavs2/build/darwin
    cd /build/libxavs2/build/darwin
    if [[ ${ARCH} == "arm64" ]]; then
        CROSS_PREFIX="aarch64-apple-darwin20-"
    fi
else
    if [[ ${ARCH} == "aarch64" ]]; then
        CONF_FLAGS="--disable-asm --disable-ffms"
    fi
    cd /build/libxavs2/build/linux
fi

./configure --prefix=${PREFIX} \
    --disable-cli --enable-static --enable-pic --disable-avs --disable-swscale --disable-lavf --disable-ffms --disable-gpac --disable-lsmash --extra-asflags="-w-macro-params-legacy" \
    ${CONF_FLAGS} --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make install | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

rm -rf /build/libxavs2

add_enable "--enable-libxavs2"

exit 0

#!/bin/bash

export LIBVPX_TARGET=""
if [[ "${ARCH}" == "aarch64" && "${TARGET_OS}" == "linux" ]]; then
    export LIBVPX_TARGET="--target=arm64-linux-gcc"
elif [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "windows" ]]; then
    export LIBVPX_TARGET="--target=${ARCH}-win64-gcc"
elif [[ "${ARCH}" == "arm64" && "${TARGET_OS}" == "darwin" ]]; then
    export LIBVPX_TARGET="--target=${ARCH}-darwin23-gcc"
elif [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "darwin" ]]; then
    export LIBVPX_TARGET="--target=${ARCH}-darwin14-gcc"
fi

cd /build/libvpx
export CROSS=${CROSS_PREFIX}
export DIST_DIR=${PREFIX}
./configure --prefix=${PREFIX} --enable-vp9-highbitdepth --enable-static --enable-pic \
    --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests ${LIBVPX_TARGET} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
rm -rf /build/libvpx

add_enable "--enable-libvpx"

exit 0

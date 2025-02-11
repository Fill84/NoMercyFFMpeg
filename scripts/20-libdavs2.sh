#!/bin/bash

EXTRA_FLAGS=""

if [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "windows" ]]; then
    cp -r /build/libdavs2/build/linux /build/libdavs2/build/windows
    cd /build/libdavs2/build/windows
elif [[ "${ARCH}" == "aarch64" && "${TARGET_OS}" == "linux" ]]; then
    cp -r /build/libdavs2/build/linux /build/libdavs2/build/aarch64
    cd /build/libdavs2/build/aarch64
    EXTRA_FLAGS="--disable-asm"
elif [[ "${ARCH}" == "arm64" && "${TARGET_OS}" == "darwin" ]]; then
    cp -r /build/libdavs2/build/linux /build/libdavs2/build/darwin-arm64
    cd /build/libdavs2/build/darwin-arm64
    CROSS_PREFIX="aarch64-apple-darwin24.1-"
elif [[ "${ARCH}" == "x86_64" && "${TARGET_OS}" == "darwin" ]]; then
    cp -r /build/libdavs2/build/linux /build/libdavs2/build/darwin-x86_64
    cd /build/libdavs2/build/darwin-x86_64
else
    cd /build/libdavs2/build/linux
fi

if [[ "${TARGET_OS}" != "darwin" ]]; then
    sed -i -e 's/EGIB/bss/g' -e 's/naidnePF/bss/g' configure
fi

./configure --prefix=${PREFIX} --disable-cli --enable-static --disable-shared --with-pic \
    --host=${CROSS_PREFIX%-} \
    --cross-prefix=${CROSS_PREFIX} ${EXTRA_FLAGS} | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
rm -rf /build/libdavs2

add_enable "--enable-libdavs2"

exit 0

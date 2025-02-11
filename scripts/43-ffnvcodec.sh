#!/bin/bash

if [[ ${TARGET_OS} == "darwin" ]]; then
    exit 255
fi

cd /build/ffnvcodec
make PREFIX=${PREFIX} install
rm -rf /build/ffnvcodec

add_enable "--enable-ffnvcodec --enable-nvenc --enable-nvdec"

exit 0

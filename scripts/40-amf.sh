#!/bin/bash

if [[ ${TARGET_OS} == "darwin" ]]; then
    exit 255
fi

cd /build/amf
mv amf/public/include ${PREFIX}/include/AMF
rm -rf /build/amf

add_enable "--enable-amf"

exit 0

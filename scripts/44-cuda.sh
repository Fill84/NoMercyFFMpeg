#!/bin/bash

if [[ ${TARGET_OS} == "darwin" ]]; then
    exit 255
fi

cp -R /usr/local/cuda/include/* ${PREFIX}/include
cp -R /usr/local/cuda/lib64/* ${PREFIX}/lib

add_enable "--enable-cuda --enable-cuda-nvcc --enable-cuvid"

exit 0

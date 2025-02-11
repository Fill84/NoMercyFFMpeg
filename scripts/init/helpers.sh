#!/bin/bash

add_enable() {
    local enable="$1"
    echo "Add enable: $enable"
    if [ -n "${FFMPEG_ENABLES}" ]; then
        FFMPEG_ENABLES+=" "
    fi
    FFMPEG_ENABLES+="$enable"
    echo "${FFMPEG_ENABLES}" >>/build/enable.txt
}

add_cflag() {
    local cflag="$1"
    echo "Add cflag: $cflag"
    if [ -n "${CFLAGS}" ]; then
        FFMPEG_CFLAGS+=" "
    fi
    FFMPEG_CFLAGS+="$cflag"
    echo "${FFMPEG_CFLAGS}" >>/build/cflags.txt
}

#!/bin/bash

hr() {                           # HR function to print a horizontal line
    local length=${1:-54}        # Default length to 54 if not provided
    if [ ${length} -le 0 ]; then # If length is less than or equal to 0
        return                   # Return without printing anything
    fi
    printf "%${length}s\n" | tr ' ' '-' # Print the provided length of dashes
}

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
    if [ -n "${FFMPEG_CFLAGS}" ]; then
        FFMPEG_CFLAGS+=" "
    fi
    FFMPEG_CFLAGS+="$cflag"
    echo "${FFMPEG_CFLAGS}" >>/build/cflags.txt
}

add_ldflag() {
    local ldflag="$1"
    echo "Add ldflag: $ldflag"
    if [ -n "${FFMPEG_LDFLAGS}" ]; then
        FFMPEG_LDFLAGS+=" "
    fi
    FFMPEG_LDFLAGS+="$ldflag"
    echo "${FFMPEG_LDFLAGS}" >>/build/ldflags.txt
}

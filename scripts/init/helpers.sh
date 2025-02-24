#!/bin/bash

hr() {                           # HR function to print a horizontal line
    local length=${1:-54}        # Default length to 54 if not provided
    if [ ${length} -le 0 ]; then # If length is less than or equal to 0
        return                   # Return without printing anything
    fi
    printf "%${length}s\n" | tr ' ' '-' # Print the provided length of dashes
}

text_with_padding() {
    local text_before="$1"
    local text_after="$2"
    local extra_padding=${3:-0}
    local text_length=$((${#text_before} + ${#text_after}))
    local padding=$((54 - text_length - extra_padding))
    # local elipse=" ..."
    # if [ $padding -lt 1 ]; then
    #     local trim_length=$((${#text_after} + ${#elipse} + 3))
    #     text_before=$(echo "$text_before" | cut -c1-$((-${trim_length})))
    #     text_before+=$elipse
    #     padding=$((54 - ${#text_before} - ${#text_after} - extra_padding))
    # fi
    printf "%s%*s%s\n" "$text_before" "$padding" "" "$text_after"
}

clean_whitespace() {
    local text="$1"
    text=$(printf "%s" "$text" | sed -E -e 's/\r$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/ /g; /^$/d;')
    printf "%s" "$text"
}

join_lines() {
    local file="$1"
    local result

    result=$(grep -v '^$' "$file" | paste -sd ' ') # Remove empty lines and join into one line

    printf "%s" "$result"
}

split_lines() {
    local file="$1"
    local result

    result=$(join_lines $file)                            # Remove empty lines and join into one line
    result=$(echo "$result" | tr ' ' '\n' | grep -v '^$') # Replace spaces with new lines and remove empty lines again

    printf "%s" "$result"
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

add_extralib() {
    local extralibflag="$1"
    echo "Add extralibflag: $extralibflag"
    if [ -n "${FFMPEG_EXTRA_LIBFLAGS}" ]; then
        FFMPEG_EXTRA_LIBFLAGS+=" "
    fi
    FFMPEG_EXTRA_LIBFLAGS+="$extralibflag"
    echo "${FFMPEG_EXTRA_LIBFLAGS}" >>/build/extra_libflags.txt
}

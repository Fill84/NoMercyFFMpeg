#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0

check_command() {
    command -v $1 >/dev/null 2>&1 || { echo "Required command $1 not found. Aborting."; exit 1; }
}

test_feature() {
    local name=$1
    local command=$2
    local expected_output=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $name... "
    
    if eval "$command" 2>&1 | grep -q "$expected_output"; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}FAILED${NC}"
    fi
}

# Check for required commands
check_command ./ffmpeg
check_command ./ffprobe

# Create test files
mkdir -p test_files
dd if=/dev/urandom of=test_files/test.raw bs=1M count=1

# Basic codec tests
test_feature "libx264" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libx264 test_files/test_h264.mp4" "encoder.*libx264"
test_feature "libx265" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libx265 test_files/test_h265.mp4" "encoder.*libx265"
test_feature "libvpx" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libvpx-vp9 test_files/test_vp9.webm" "encoder.*libvpx"
test_feature "libopus" "./ffmpeg -y -f lavfi -i anullsrc=duration=1 -c:a libopus test_files/test_opus.opus" "encoder.*libopus"
test_feature "libmp3lame" "./ffmpeg -y -f lavfi -i anullsrc=duration=1 -c:a libmp3lame test_files/test_mp3.mp3" "encoder.*libmp3lame"

# Hardware acceleration tests
test_feature "NVENC" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v h264_nvenc test_files/test_nvenc.mp4" "encoder.*h264_nvenc"
test_feature "VAAPI" "./ffmpeg -y -vaapi_device /dev/dri/renderD128 -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -vf 'format=nv12,hwupload' -c:v h264_vaapi test_files/test_vaapi.mp4 2>&1" "vaapi"

# Image format tests
test_feature "libwebp" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=640x480:rate=1 -frames:v 1 -c:v libwebp test_files/test.webp" "encoder.*libwebp"
test_feature "libopenjpeg" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=640x480:rate=1 -frames:v 1 -c:v libopenjpeg test_files/test.jp2" "encoder.*openjpeg"

# Subtitle and text tests
test_feature "libass" "./ffmpeg -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -vf ass=test_files/test.ass test_files/test_ass.mp4" "ass"
test_feature "libfribidi" "./ffmpeg -filters 2>&1 | grep fribidi" "fribidi"

# Audio processing tests
test_feature "libfdk_aac" "./ffmpeg -y -f lavfi -i anullsrc=duration=1 -c:a libfdk_aac test_files/test_aac.m4a" "encoder.*libfdk_aac"
test_feature "libvorbis" "./ffmpeg -y -f lavfi -i anullsrc=duration=1 -c:a libvorbis test_files/test_vorbis.ogg" "encoder.*libvorbis"

# Additional format tests
test_feature "libbluray" "./ffmpeg -h 2>&1 | grep bluray" "bluray"
test_feature "libcdio" "./ffmpeg -h 2>&1 | grep cdio" "cdio"
test_feature "libsrt" "./ffmpeg -h 2>&1 | grep srt" "srt"
test_feature "libxml2" "./ffmpeg -h 2>&1 | grep xml" "xml"

# AV1 codec tests
test_feature "libdav1d" "./ffmpeg -h decoder 2>&1 | grep dav1d" "dav1d"
test_feature "librav1e" "./ffmpeg -h encoder 2>&1 | grep rav1e" "rav1e"

# Cleanup
rm -rf test_files

# Print summary
echo "----------------------------------------"
echo "Test Summary:"
echo "Total tests: $TOTAL_TESTS"
echo "Passed tests: $PASSED_TESTS"
echo "Failed tests: $((TOTAL_TESTS - PASSED_TESTS))"
echo "----------------------------------------"
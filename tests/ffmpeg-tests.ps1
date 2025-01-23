# Test counter
$script:TOTAL_TESTS = 0
$script:PASSED_TESTS = 0

function Check-Command {
    param (
        [string]$Command
    )
    if (-not (Test-Path $Command -PathType Leaf)) {
        Write-Host "Required command $Command not found. Aborting." -ForegroundColor Red
        exit 1
    }
}

function Test-Feature {
    param (
        [string]$Name,
        [string]$Command,
        [string]$ExpectedOutput
    )

    $script:TOTAL_TESTS++
    Write-Host -NoNewline "Testing $Name... "

    try {
        $output = Invoke-Expression "$Command 2>&1" | Out-String
        if ($output -cmatch $ExpectedOutput) {
            Write-Host "PASSED" -ForegroundColor Green
            $script:PASSED_TESTS++
        } else {
            Write-Host "FAILED" -ForegroundColor Red
        }
    } catch {
        Write-Host "FAILED (Error)" -ForegroundColor Red
    }
}

# Check for required commands
Check-Command ".\ffmpeg.exe"
Check-Command ".\ffprobe.exe"

# Create test files
New-Item -ItemType Directory -Path test_files -Force | Out-Null

# Create a 1MB random file
$randomBytes = New-Object Byte[] 1048576
(New-Object Random).NextBytes($randomBytes)
[System.IO.File]::WriteAllBytes("test_files/test.raw", $randomBytes)

# Basic codec tests
Test-Feature "libx264" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libx264 test_files/test_h264.mp4" "encoder.*libx264"
Test-Feature "libx265" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libx265 test_files/test_h265.mp4" "encoder.*libx265"
Test-Feature "libvpx" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v libvpx-vp9 test_files/test_vp9.webm" "encoder.*libvpx"
Test-Feature "libopus" ".\ffmpeg.exe -y -f lavfi -i anullsrc=duration=1 -c:a libopus test_files/test_opus.opus" "encoder.*libopus"
Test-Feature "libmp3lame" ".\ffmpeg.exe -y -f lavfi -i anullsrc=duration=1 -c:a libmp3lame test_files/test_mp3.mp3" "encoder.*libmp3lame"

# Hardware acceleration tests
Test-Feature "NVENC" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v h264_nvenc test_files/test_nvenc.mp4" "encoder.*h264_nvenc"
Test-Feature "VAAPI" ".\ffmpeg.exe -y -vaapi_device /dev/dri/renderD128 -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -vf 'format=nv12,hwupload' -c:v h264_vaapi test_files/test_vaapi.mp4 2>&1" "vaapi"

# Image format tests
Test-Feature "libwebp" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=640x480:rate=1 -frames:v 1 -c:v libwebp test_files/test.webp" "encoder.*libwebp"
Test-Feature "libopenjpeg" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=640x480:rate=1 -frames:v 1 -c:v libopenjpeg test_files/test.jp2" "encoder.*openjpeg"

# Subtitle and text tests
Test-Feature "libass" ".\ffmpeg.exe -y -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -vf ass=test_files/test.ass test_files/test_ass.mp4" "ass"
Test-Feature "libfribidi" ".\ffmpeg.exe -filters 2>&1 | findstr fribidi" "fribidi"

# Audio processing tests
Test-Feature "libfdk_aac" ".\ffmpeg.exe -y -f lavfi -i anullsrc=duration=1 -c:a libfdk_aac test_files/test_aac.m4a" "encoder.*libfdk_aac"
Test-Feature "libvorbis" ".\ffmpeg.exe -y -f lavfi -i anullsrc=duration=1 -c:a libvorbis test_files/test_vorbis.ogg" "encoder.*libvorbis"

# Additional format tests
Test-Feature "libbluray" ".\ffmpeg.exe -h 2>&1 | findstr bluray" "bluray"
Test-Feature "libcdio" ".\ffmpeg.exe -h 2>&1 | findstr cdio" "cdio"
Test-Feature "libsrt" ".\ffmpeg.exe -h 2>&1 | findstr srt" "srt"
Test-Feature "libxml2" ".\ffmpeg.exe -h 2>&1 | findstr xml" "xml"

# AV1 codec tests
Test-Feature "libdav1d" ".\ffmpeg.exe -h decoder 2>&1 | findstr dav1d" "dav1d"
Test-Feature "librav1e" ".\ffmpeg.exe -h encoder 2>&1 | findstr rav1e" "rav1e"

# Cleanup
Remove-Item -Path test_files -Recurse -Force

# Print summary
Write-Host "----------------------------------------"
Write-Host "Test Summary:"
Write-Host "Total tests: $script:TOTAL_TESTS"
Write-Host "Passed tests: $script:PASSED_TESTS"
Write-Host "Failed tests: $($script:TOTAL_TESTS - $script:PASSED_TESTS)"
Write-Host "----------------------------------------"
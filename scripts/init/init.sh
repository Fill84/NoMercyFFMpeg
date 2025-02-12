#!/bin/bash

echo "------------------------------------------------------------"
echo "📦 Building FFmpeg for ${TARGET_OS^} ${ARCH}"
echo "------------------------------------------------------------"
echo "🔍 Checking for scripts..."

total_count=$(ls /scripts | wc -l)
current_count=0
success_count=0
skipped_count=0
failed_count=0

sleep 1
echo ""
echo "🧮 ${total_count} scripts found"
echo "------------------------------------------------------------"
echo "🚧 Start building FFmpeg components"
echo "------------------------------------------------------------"

mkdir -p /logs
. /init/helpers.sh
export -f add_enable add_cflag
total_time=0

for i in $(ls /scripts); do
    if [[ $i == "add_enable.sh" || $i == "init.sh" || $i == "init" ]]; then
        continue
    fi
    chmod +x /scripts/$i
    current_count=$((current_count + 1))
    name="${i#*-}"     # Remove the prefix
    name="${name%.sh}" # Remove the suffix
    name="${name^^}"   # Uppercase
    width=40
    padding=$((width - ${#name}))
    printf "🛠️ Building %s %${padding}s[%02d/%02d]\n" "$name" "" "$current_count" "$total_count"
    start_time=$(date +%s)
    /scripts/$i >/dev/null 2>&1
    result=$?
    if [ ${result} -eq 255 ]; then # This is skipped
        echo "➖ ${name} was skipped"
        skipped_count=$((skipped_count + 1))
    elif [ ${result} -eq 0 ]; then # This is success
        end_time=$(($(date +%s) - ${start_time}))
        end_time_string=$(printf "%02d%s" $end_time "s")
        if [ $end_time -gt 60 ]; then
            end_time=$(($end_time / 60))
            end_time_string=$(printf "%02d%s" $end_time "m")
        fi
        padding2=$((padding - ${#end_time_string} - 12))
        printf "✅ %s was built successfully %${padding2}s [ %s ]\n" "$name" "" "$end_time_string"
        success_count=$((success_count + 1))
    else # This is failure
        end_time=$(($(date +%s) - ${start_time}))
        end_time_string=$(printf "%02d%s" $end_time "s")
        if [ $end_time -gt 60 ]; then
            end_time=$(($end_time / 60))
            end_time_string=$(printf "%02d%s" $end_time "m")
        fi
        padding2=$((padding - ${#end_time_string} - 12))
        # echo "printing error log: $(cat /ffmpeg_build.log)"
        printf "❌ %s build failed %${padding2}s [ %s ]\n" "$name" "" "$end_time_string"
        failed_count=$((failed_count + 1))
    fi
    total_time=$((total_time + end_time))
done

echo "------------------------------------------------------------"
echo "📊 Summary:"
echo "------------------------------------------------------------"
echo "   Total scripts: ${total_count}"
echo "   Successful builds: ${success_count}"
echo "   Skipped builds: ${skipped_count}"
echo "   Failed builds: ${failed_count}"
echo "   Total build time: ${total_time} seconds"
echo "------------------------------------------------------------"

exit 0

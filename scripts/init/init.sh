#!/bin/bash

#region info
#---------------------------------------------------------------------------------------------------------#
#
# This script is the entry point for the FFmpeg build process.
# It will execute all the scripts in the /scripts directory in order.
# Each script is responsible for building a specific component of FFmpeg.
#
# The script will exit with a status code of 0 if all builds are successful.
# If any build fails, the script will exit with a status code of 1.
# If you want to skip a script for a specific target "${TARGET_OS}", you can exit 255 from the script.
#
# You can enable debug mode by setting the DEBUG environment variable to "true".
# When debug mode is enabled, the script will print the output of the failed build and exit.
#
# The script will print the name of the component being built and the progress of the build.
# The script will print a summary of the build process at the end.
# The summary will include the total number of scripts, successful builds, skipped builds,
#    failed builds, and the total build time.
#
# You can use the helper functions defined in the /scripts/init/helpers.sh file.
#
# The helper functions "add_cflag" "add_ldflag" are used to add flags to the CFLAGS and
#    LDFLAGS environment variables.
#
# You can use "add_cflag" to add a flag to the CFLAGS environment variable.
#    For example, to add "-I/usr/local/include" to CFLAGS, you can use "add_cflag -I/usr/local/include".
# You can use "add_ldflag" to add a flag to the LDFLAGS environment variable.
#    For example, to add "-L/usr/local/lib" to LDFLAGS, you can use "add_ldflag -L/usr/local/lib".
#
# The helper function "add_enable" is used to enable a component in FFmpeg.
# You can use "add_enable" to enable a component in FFmpeg.
#    For example, to enable libx264, you can use "add_enable --enable-libx264".
#
# The helper function "hr" is used to print a horizontal line.
# You can use "hr" to print a horizontal line.
#    For example, to print a horizontal line of length 54, you can use "hr 54".
#
#---------------------------------------------------------------------------------------------------------#
#endregion

#region variables
total_time=0
total_count=0
current_count=0
success_count=0
skipped_count=0
failed_count=0
#endregion

#region main
printf "%54s\n" | tr ' ' '-' # Print a horizontal line
echo "📦 Building FFmpeg for ${TARGET_OS^} ${ARCH}"
if [[ ${DEBUG} == "true" ]]; then
    echo "🐞 Debug mode is enabled 🐞"
fi
printf "%54s\n" | tr ' ' '-' # Print a horizontal line
#endregion

#region helpers
echo "⚙️ Registering helper functions"

mkdir -p /logs
. /scripts/init/helpers.sh
export -f hr add_enable add_cflag add_ldflag

echo "✅ Helper functions registered"
hr # Print a horizontal line
#endregion

#region scripts
echo "🔍 Checking for scripts..."

if [[ ${TARGET_OS} == "darwin" ]]; then
    mv /scripts/init/00-platformversion.sh /scripts/00-platformversion.sh
fi

files=(/scripts/*.sh)    # Expand matching .sh files into an array
total_count=${#files[@]} # Get the count of matching files
# total_count=$(ls /scripts | wc -l) # Alternative way to get the count of matching files but it may include other files then .sh files

echo "🧮 ${total_count} scripts found"
hr # Print a horizontal line

echo "🚧 Start building FFmpeg components"
hr # Print a horizontal line
#endregion

#region build
for i in /scripts/*.sh; do
    # Ensure the glob expanded to actual files
    [[ -f "$i" ]] || continue
    chmod +x $i
    current_count=$((current_count + 1))
    name="${i#*-}"     # Remove the prefix
    name="${name%.sh}" # Remove the suffix
    name="${name^^}"   # Uppercase
    width=34
    padding=$((width - ${#name}))
    printf "🛠️ Building %s %${padding}s[%02d/%02d]\n" "$name" "" "$current_count" "$total_count"
    start_time=$(date +%s)
    $i >/dev/null 2>&1
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
        if [[ ${DEBUG} == "true" ]]; then
            cat /ffmpeg_build.log
            exit 1
        fi
        end_time=$(($(date +%s) - ${start_time}))
        end_time_string=$(printf "%02d%s" $end_time "s")
        if [ $end_time -gt 60 ]; then
            end_time=$(($end_time / 60))
            end_time_string=$(printf "%02d%s" $end_time "m")
        fi
        padding2=$((padding - ${#end_time_string} - 12))
        printf "❌ %s build failed %${padding2}s [ %s ]\n" "$name" "" "$end_time_string"
        failed_count=$((failed_count + 1))
    fi
    total_time=$((total_time + end_time))
done
#endregion

#region summary
hr # Print a horizontal line
echo "📊 Summary:"
hr # Print a horizontal line
echo "   Total scripts: ${total_count}"
echo "   Successful builds: ${success_count}"
echo "   Skipped builds: ${skipped_count}"
echo "   Failed builds: ${failed_count}"
echo "   Total build time: ${total_time} seconds"
hr # Print a horizontal line
#endregion

#region exit
exit 0
#endregion

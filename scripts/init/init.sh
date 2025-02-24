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
mkdir -p ${PREFIX}/lib ${PREFIX}/lib/pkgconfig ${PREFIX}/include ${PREFIX}/bin

printf "%54s\n" | tr ' ' '-' # Print a horizontal line
echo "       _   _       __  __                      "
echo "      | \ | | ___ |  \/  | ___ _ __ ___ _   _  "
echo "      |  \| |/ _ \| |\/| |/ _ \ '__/ __| | | | "
echo "      | |\  | (_) | |  | |  __/ | | (__| |_| | "
echo "      |_| \_|\___/|_|  |_|\___|_|  \___|\__, | "
echo "        _____ _____ __  __ ____  _____ _|___/  "
echo "       |  ___|  ___|  \/  |  _ \| ____/ ___|   "
echo "       | |_  | |_  | |\/| | |_) |  _|| |  _    "
echo "       |  _| |  _| | |  | |  __/| |__| |_| |   "
echo "       |_|   |_|   |_|  |_|_|   |_____\____|   "
echo ""
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
export -f hr text_with_padding add_enable add_cflag add_ldflag add_extralib join_lines split_lines clean_whitespace

text_with_padding "✅ Helper functions registered" ""
hr # Print a horizontal line
#endregion

#region scripts
text_with_padding "🔍 Checking for scripts..." ""

if [[ ${TARGET_OS} == "darwin" ]]; then
    mv /scripts/init/00-platformversion.sh /scripts/00-platformversion.sh
elif [[ ${TARGET_OS} == "windows" ]]; then
    mv /scripts/init/00-rcinfo.sh /scripts/00-rcinfo.sh
fi

files=(/scripts/*.sh)    # Expand matching .sh files into an array
total_count=${#files[@]} # Get the count of matching files
string_total_count=$(printf "%02d" $total_count)
# total_count=$(ls /scripts | wc -l) # Alternative way to get the count of matching files but it may include other files then .sh files

text_with_padding "🧮 ${total_count} scripts found" ""
hr # Print a horizontal line

text_with_padding "🚧 Start building FFmpeg components" ""
hr # Print a horizontal line
#endregion

#region build
for i in /scripts/*.sh; do
    # Ensure the glob expanded to actual files
    [[ -f "$i" ]] || continue
    chmod +x $i
    current_count=$((current_count + 1))
    string_current_count=$(printf "%02d" $current_count)
    name="${i#*-}"     # Remove the prefix
    name="${name%.sh}" # Remove the suffix
    name="${name^^}"   # Uppercase
    text_with_padding "🛠️ Building ${name}" "[${string_current_count}/${string_total_count}]" -5
    start_time=$(date +%s)
    $i >/dev/null 2>&1
    result=$?
    if [ ${result} -eq 255 ]; then # This is skipped
        text_with_padding "➖ ${name} was skipped" ""
        skipped_count=$((skipped_count + 1))
    elif [ ${result} -eq 0 ]; then # This is success
        if [[ ${DEBUG} == "true" ]]; then
            if [[ -f /ffmpeg_build.log ]]; then
                logtext=$(clean_whitespace "$(cat /ffmpeg_build.log)")
                if [[ -n "${logtext}" ]]; then
                    printf "%s\n" "📃 Log: ${logtext}"
                fi
                rm -f /ffmpeg_build.log
            fi
        fi
        end_time=$(($(date +%s) - ${start_time}))
        end_time_string=$(printf "%02d%s" $end_time "s")
        if [ $end_time -gt 60 ]; then
            min_end_time=$(($end_time / 60))
            end_time_string=$(printf "%02d%s" $min_end_time "m")
        fi
        text_with_padding "✅ ${name} was built successfully" "[ ${end_time_string} ]" -1
        success_count=$((success_count + 1))
    else # This is failure
        if [[ ${DEBUG} == "true" ]]; then
            logtext=$(clean_whitespace "$(cat /ffmpeg_build.log)")
            if [[ -n "${logtext}" ]]; then
                printf "%s\n" "📃 Log: ${logtext}"
            fi
            rm -f /ffmpeg_build.log
            exit 1
        fi
        end_time=$(($(date +%s) - ${start_time}))
        end_time_string=$(printf "%02d%s" $end_time "s")
        if [ $end_time -gt 60 ]; then
            min_end_time=$(($end_time / 60))
            end_time_string=$(printf "%02d%s" $min_end_time "m")
        fi
        text_with_padding "❌ ${name} build failed" "[ ${end_time_string} ]" -1
        failed_count=$((failed_count + 1))
    fi
    total_time=$((total_time + end_time))
done
hr # Print a horizontal line
#endregion

#region summary
text_with_padding "📊 Summary:" ""
hr # Print a horizontal line
text_with_padding "   Total scripts:" "${total_count}"
text_with_padding "   Successful builds:" "${success_count}"
text_with_padding "   Skipped builds:" "${skipped_count}"
text_with_padding "   Failed builds:" "${failed_count}"
text_with_padding "   Total build time:" "${total_time} seconds"
hr # Print a horizontal line
#endregion

#region enabled components
local_enables=$(split_lines "/build/enable.txt")
local_enables_count=$(echo "${local_enables}" | wc -l)
text_with_padding "📃 Enabled components:" "[ ${local_enables_count} ]" -2
hr # Print a horizontal line
for enable in $local_enables; do
    text_with_padding "   ${enable}" ""
done
hr # Print a horizontal line
#endregion

#region extra libflags
local_libflags=$(split_lines "/build/extra_libflags.txt")
local_libflags_count=$(echo "${local_libflags}" | wc -l)
text_with_padding "📃 Extra libraries:" "[ ${local_libflags_count} ]" -2
hr # Print a horizontal line
for libflag in $local_libflags; do
    text_with_padding "   ${libflag}" ""
done
echo "$(join_lines "/build/extra_libflags.txt")" >/build/extra_libflags.txt
hr # Print a horizontal line
#endregion

#region exit
exit 0
#endregion

#!/bin/bash

if [[ ${TARGET_OS} != "darwin" ]]; then
    exit 255
fi

mkdir -p /Library/Preferences/
touch /Library/Preferences/com.apple.dt.Xcode.plist

echo '#include <stdio.h>\n\
int __isPlatformVersionAtLeast(int major, int minor, int patch) {\n\
return 1; // Assume the platform version is always compatible\n\
}' >platformversion.c

${CC} -c platformversion.c -o platformversion.o
${AR} rcs libplatformversion.a platformversion.o
cp libplatformversion.a ${PREFIX}/lib/

add_ldflag "-lplatformversion"

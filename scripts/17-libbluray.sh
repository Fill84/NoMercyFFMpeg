#!/bin/bash

# libgpg-error
cd /build/libgpg-error
if [[ ${TARGET_OS} == "darwin" ]]; then
    if [[ ${ARCH} == "arm64" ]]; then
        cp src/syscfg/lock-obj-pub.${ARCH%64}-apple-darwin.h src/syscfg/lock-obj-pub.darwin24.1.h
    else
        cp src/syscfg/lock-obj-pub.${ARCH}-apple-darwin.h src/syscfg/lock-obj-pub.${CROSS_PREFIX%-}.h
    fi
fi

./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "libgpg-error configure failed" >>/ffmpeg_build.log
    exit 1
fi
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libgpg-error.pc
rm -rf /build/libgpg-error

# libgcrypt
EXTRA_FLAGS=""
cd /build/libgcrypt
if [[ ${TARGET_OS} == "darwin" ]]; then
    EXTRA_FLAGS="--disable-asm --disable-test"
fi
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc ${EXTRA_FLAGS} \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc ${EXTRA_FLAGS} \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "libgcrypt configure failed" >>/ffmpeg_build.log
    exit 1
fi
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libgcrypt.pc

echo '#!/bin/sh' >/usr/local/bin/libgcrypt-config
echo 'pkg-config libgcrypt "$@"' >>/usr/local/bin/libgcrypt-config
chmod +x /usr/local/bin/libgcrypt-config

echo '#!/bin/sh' >/usr/local/bin/gpg-error-config
echo 'pkg-config libgpg-error "$@"' >>/usr/local/bin/gpg-error-config
chmod +x /usr/local/bin/gpg-error-config
rm -rf /build/libgcrypt

# libbdplus
cd /build/libbdplus
./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "libbdplus configure failed" >>/ffmpeg_build.log
    exit 1
fi
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libbdplus.pc
rm -rf /build/libbdplus

# libaacs
mkdir -p ~/.config/aacs/ /usr/local/etc/aacs/ /etc/aacs/

cd /build/libaacs
rm -f /build/libaacs/KEYDB.cfg
wget https://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -O /build/libaacs/KEYDB.cfg
ln -s ./KEYDB.cfg src/KEYDB.cfg
ln -s ./KEYDB.cfg src/file/KEYDB.cfg
ln -s ./KEYDB.cfg ~/.config/aacs/KEYDB.cfg
ln -s ./KEYDB.cfg /usr/local/etc/aacs/KEYDB.cfg
ln -s ./KEYDB.cfg /etc/aacs/KEYDB.cfg

INPUT_FILE="KEYDB.cfg"
OUTPUT_FILE="/src/file/keydb_embedded.h"
# Read binary file and convert to C array format
HEX_ARRAY=$(od -An -tx1 -v "$INPUT_FILE" | tr -s ' ' | tr ' ' ',' | sed 's/,/, /g')

# Get file size
FILE_SIZE=$(wc -c <"$INPUT_FILE")

# Write to output file
{
    echo "unsigned char KEYDB_cfg[] = { $HEX_ARRAY };"
    echo "unsigned int KEYDB_cfg_len = $FILE_SIZE;"
} >"$OUTPUT_FILE"

./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-} | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "libaacs configure failed" >>/ffmpeg_build.log
    exit 1
fi
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libaacs.pc
rm -rf /build/libaacs

# libbluray
EXTRA_LIBS="-L${PREFIX}/lib -laacs -lbdplus"
cd /build/libbluray
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.c
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.h
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/disc.c
cd /build/libbluray
./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 --with-libaacs \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus"
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 --with-libaacs \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" | tee /ffmpeg_build.log
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
echo "Libs.private: -laacs -lbdplus -lstdc++" >>${PREFIX}/lib/pkgconfig/libbluray.pc
rm -rf /build/libbluray
EXTRA_LIBS=""

add_enable "--enable-libbluray"
add_extralib "-laacs -lbdplus"

exit 0

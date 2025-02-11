#!/bin/bash

# libgpg-error
cd /build/libgpg-error
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libgpg-error.pc
rm -rf /build/libgpg-error

# libgcrypt
cd /build/libgcrypt
./autogen.sh --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
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
    --host=${CROSS_PREFIX%-}
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libbdplus.pc
rm -rf /build/libbdplus

# libaacs
cd /build/libaacs
./bootstrap --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
./configure --prefix=${PREFIX} --libdir=${PREFIX}/lib --enable-static --disable-shared --with-pic --disable-doc \
    --host=${CROSS_PREFIX%-}
make -j$(nproc) && make install
echo "Libs.private: -lstdc++" >>${PREFIX}/lib/pkgconfig/libaacs.pc
rm -rf /build/libaacs

# libbluray
export EXTRA_LIBS="-L${PREFIX}/lib -laacs -lbdplus"
cd /build/libbluray
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.c
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/dec.h
sed -i 's/dec_init/libbluray_dec_init/g' src/libbluray/disc/disc.c
cd /build/libbluray
./bootstrap --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus"
./configure --prefix=${PREFIX} --enable-static --disable-shared --with-pic --with-libxml2 \
    --disable-doxygen-doc --disable-doxygen-dot --disable-doxygen-html --disable-doxygen-ps --disable-doxygen-pdf --disable-examples --disable-bdjava-jar \
    --host=${CROSS_PREFIX%-} \
    LIBS="-laacs -lbdplus" | tee /ffmpeg_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    exit 1
fi

make -j$(nproc) && make install
echo "Libs.private: -laacs -lbdplus -lstdc++" >>${PREFIX}/lib/pkgconfig/libbluray.pc
rm -rf /build/libbluray
export EXTRA_LIBS=""

add_enable "--enable-libbluray"

exit 0

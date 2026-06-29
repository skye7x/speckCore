#!/bin/sh

export PKG_CONFIG_SYSROOT_DIR="$SPECK_SYSROOT"
export PKG_CONFIG_LIBDIR="$SPECK_SYSROOT/usr/lib/pkgconfig:$SPECK_SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_SYSTEM_LIBRARY_PATH=""
export PKG_CONFIG_SYSTEM_INCLUDE_PATH=""

exec /usr/bin/pkg-config "$@"

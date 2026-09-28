#!/bin/bash
# Runs INSIDE the trixie build container after build.sh
set -euo pipefail
export SOURCE_DATE_EPOCH=$(git -C /src/quickshell log -1 --format=%ct)
VER=0.3.1-1~xcloud+deb13u1
P=/src/pkg
QMLDEPS="qt6-svg-plugins"
rm -rf $P && DESTDIR=$P cmake --install /src/build >/dev/null
# drop vendored cpptrace dev files (statically linked into the binary)
rm -rf $P/usr/include $P/usr/lib/x86_64-linux-gnu/cmake $P/usr/lib/x86_64-linux-gnu/libcpptrace.a
# keep .symtab for the crash reporter, drop DWARF to shrink
strip --strip-debug $P/usr/bin/quickshell
install -Dm644 /src/quickshell/LICENSE $P/usr/share/doc/quickshell/copyright
cat /src/quickshell/LICENSE-GPL >> $P/usr/share/doc/quickshell/copyright
# shlibdeps
mkdir -p /tmp/sd/debian && cd /tmp/sd && printf "Source: quickshell\n\nPackage: quickshell\nArchitecture: amd64\n" > debian/control
SHLIBS=$(dpkg-shlibdeps -O -e$P/usr/bin/quickshell 2>/dev/null | sed "s/^shlibs:Depends=//")
mkdir -p $P/DEBIAN
cat > $P/DEBIAN/control <<CTL
Package: quickshell
Version: $VER
Architecture: amd64
Maintainer: xcloud <marius@xcloud.gg>
Installed-Size: $(du -sk --exclude=DEBIAN $P | cut -f1)
Depends: $SHLIBS, __QMLDEPS__
Recommends: qml6-module-qtquick, qml6-module-qtquick-layouts, qml6-module-qtquick-controls, qml6-module-qtquick-effects, qml6-module-qtquick-shapes, fonts-dejavu-core
Section: x11
Priority: optional
Homepage: https://quickshell.org
Description: QtQuick-based desktop shell toolkit (X11/i3 build)
 Quickshell $VER built from upstream tag v0.3.1
 (1a4716cde794a59928d9d9fc15f2afc7a95de360) for Debian trixie.
 Built with -DWAYLAND=OFF (trixie wayland-protocols 1.44 is too old);
 X11 PanelWindow, Quickshell.I3 IPC, Pipewire, Mpris, SystemTray,
 Notifications, UPower, Bluetooth, Networking, Pam, Polkit, Greetd enabled.
CTL
sed -i "s/, __QMLDEPS__/${QMLDEPS:+, $QMLDEPS}/" $P/DEBIAN/control
cat $P/DEBIAN/control
mkdir -p /src/out
dpkg-deb --root-owner-group -Zxz --build $P /src/out/quickshell_${VER}_amd64.deb

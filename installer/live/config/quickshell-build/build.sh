#!/bin/bash
# Runs INSIDE the trixie nspawn container; /src is bind-mounted from /home/xcloud/qs-build/src
set -euo pipefail
export SOURCE_DATE_EPOCH=$(git -C /src/quickshell log -1 --format=%ct)
cd /src/quickshell
rm -rf /src/build
cmake -GNinja -B /src/build \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib/x86_64-linux-gnu \
  -DINSTALL_QML_PREFIX=lib/x86_64-linux-gnu/qt6/qml \
  -DDISTRIBUTOR="xcloud baldr (Debian trixie build)" \
  -DGIT_REVISION=$(git rev-parse HEAD) \
  -DWAYLAND=OFF \
  -DVENDOR_CPPTRACE=ON \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -DFETCHCONTENT_SOURCE_DIR_CPPTRACE=/src/cpptrace \
  -DCPPTRACE_USE_EXTERNAL_LIBDWARF=ON -DCPPTRACE_FIND_LIBDWARF_WITH_PKGCONFIG=ON \
  -DCPPTRACE_USE_EXTERNAL_ZSTD=ON
ninja -C /src/build -j12

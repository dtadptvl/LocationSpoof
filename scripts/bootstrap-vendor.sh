#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT="$ROOT/Vendor/idevice"
COMMIT="94bc9e8cf3b41f32f125f046abf33d913f4e1b2d"
mkdir -p "$OUT"
curl -fL "https://raw.githubusercontent.com/StikDebug/StikDebug/$COMMIT/StikDebug/idevice/idevice.h" -o "$OUT/idevice.h"
curl -fL "https://raw.githubusercontent.com/StikDebug/StikDebug/$COMMIT/StikDebug/idevice/libidevice_ffi.a" -o "$OUT/libidevice_ffi.a"
echo "Vendored idevice from StikDebug commit $COMMIT"

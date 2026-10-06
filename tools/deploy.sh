#!/bin/bash
# Copies the app and a freshly converted database onto a device over adb and
# makes the launcher pick it up. For development; the recipe does the real
# install. Usage: tools/deploy.sh <Flipper-IRDB checkout> [adb serial]
set -e
cd "$(dirname "$0")/.."
ID=org.webosports.app.remote
DEST=/usr/palm/applications/$ID
IRDB=${1:?usage: tools/deploy.sh <Flipper-IRDB checkout> [adb serial]}
ADB="adb${2:+ -s $2}"
OUT=build/irdb

python3 -I tools/build-irdb.py "$IRDB" "$OUT"

$ADB shell rm -rf "$DEST"
$ADB shell mkdir -p "$DEST"
$ADB push appinfo.json icon.png qml "$DEST/" >/dev/null
$ADB push "$OUT" "$DEST/irdb" >/dev/null

LS2=/usr/share/luna-service2
sed 's|@[A-Z_]*@||g' sysbus/$ID.manifest.json.in > build/$ID.manifest.json
$ADB push sysbus/$ID.app.json $LS2/roles.d/ >/dev/null
$ADB push build/$ID.manifest.json $LS2/manifests.d/ >/dev/null
$ADB push sysbus/$ID.perm.json $LS2/client-permissions.d/ >/dev/null
$ADB shell "ls-control scan-services >/dev/null 2>&1; luna-send -n 1 luna://com.webos.service.applicationmanager/rescan {} >/dev/null 2>&1 || luna-send -n 1 luna://com.palm.applicationManager/rescan {}" >/dev/null
echo "deployed $ID"

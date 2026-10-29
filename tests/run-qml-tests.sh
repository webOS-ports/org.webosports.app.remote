#!/bin/sh
# Runs the QML tests on the build host: the remotes page (tests/qml/tst_ui.qml)
# with luneos-components' desktop stand-ins for the bus and the window.
#
#   tests/run-qml-tests.sh [path to luneos-components [qmltestrunner arguments]]
#
# luneos-components needs its desktop build (CONFIG+=desktop, see its
# README) for the style and LuneOS.Components plugins. Each state is also
# saved as a screenshot in build/test-output/ui/<state>.png.
#
# A Qt 6 qmltestrunner is looked for before the one on PATH: on Debian and
# Ubuntu that one is often qtchooser's wrapper, which runs Qt 5's.
set -e
cd "$(dirname "$0")/.."
LC=${1:-../luneos-components}
[ $# -gt 0 ] && shift
if [ -z "${QMLTESTRUNNER:-}" ]; then
    for candidate in /usr/lib/qt6/bin/qmltestrunner "$(command -v qmltestrunner)"; do
        if [ -x "$candidate" ]; then
            QMLTESTRUNNER=$candidate
            break
        fi
    done
fi
mkdir -p build/test-output/ui
CONF=$(mktemp -d)
trap 'rm -rf "$CONF"' EXIT
# The saved remotes (LocalStorage) and the preferences go to a throwaway
# directory, not the user's.
XDG_CONFIG_HOME=$CONF XDG_DATA_HOME=$CONF/data XDG_CACHE_HOME=$CONF/cache \
QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-offscreen} \
QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS \
    "$QMLTESTRUNNER" \
    -import "$LC/modules" -import "$LC/test/imports" \
    -input tests/qml "$@"

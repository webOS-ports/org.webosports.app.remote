/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2

// Units & font sizes
import LunaNext.Common 0.1

/*
 * The up/down pair of a physical remote - volume, channel, temperature, fan
 * speed - with what it changes written between the two keys.
 */
Rectangle {
    id: rocker

    property string label
    property var upButton: null
    property var downButton: null
    property real keySize: Units.gu(8)

    visible: upButton !== null || downButton !== null
    width: keySize
    height: column.height + Units.gu(1)
    radius: keySize / 2
    color: "#a8a8a8"

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        y: Units.gu(0.5)
        spacing: Units.gu(0.5)

        RemoteKey {
            width: rocker.keySize - Units.gu(1)
            height: width
            button: rocker.upButton
            caption: "+"
            repeat: true
            visible: true
            enabled: rocker.upButton !== null
            font.pixelSize: FontUtils.sizeToPixels("x-large")
        }

        Label {
            width: rocker.keySize - Units.gu(1)
            horizontalAlignment: Text.AlignHCenter
            text: rocker.label
            font.pixelSize: FontUtils.sizeToPixels("small")
            font.weight: Font.Bold
            color: "#333"
        }

        RemoteKey {
            width: rocker.keySize - Units.gu(1)
            height: width
            button: rocker.downButton
            caption: "−"
            repeat: true
            visible: true
            enabled: rocker.downButton !== null
            font.pixelSize: FontUtils.sizeToPixels("x-large")
        }
    }
}

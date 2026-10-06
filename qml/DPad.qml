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

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

/* Arrow keys around OK, on a round pad like the remotes they stand in for */
Rectangle {
    id: pad

    property var slots: ({})
    property real size: Units.gu(24)

    readonly property real keySize: size / 3.3

    visible: slots.up !== undefined || slots.down !== undefined ||
             slots.left !== undefined || slots.right !== undefined
    width: size
    height: size
    radius: size / 2
    color: "#a8a8a8"

    RemoteKey {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Units.gu(0.5)
        width: pad.keySize; height: pad.keySize
        button: pad.slots.up || null
        caption: "▲︎"
        repeat: true
    }

    RemoteKey {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Units.gu(0.5)
        width: pad.keySize; height: pad.keySize
        button: pad.slots.down || null
        caption: "▼︎"
        repeat: true
    }

    RemoteKey {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Units.gu(0.5)
        width: pad.keySize; height: pad.keySize
        button: pad.slots.left || null
        caption: "◄"
        repeat: true
    }

    RemoteKey {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Units.gu(0.5)
        width: pad.keySize; height: pad.keySize
        button: pad.slots.right || null
        caption: "►"
        repeat: true
    }

    RemoteKey {
        anchors.centerIn: parent
        width: pad.keySize * 1.15; height: width
        button: pad.slots.ok || null
        caption: "OK"
        keyColour: LuneOSButton.affirmativeColor
    }
}

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

/*
 * One line of trouble under the header: no transmitter, or a key that did
 * not go out. Same colours as the settings apps' ServiceUnavailableNotice, so
 * it reads as the same kind of message.
 */
Rectangle {
    id: notice

    property alias text: noticeLabel.text

    signal dismissed()

    implicitHeight: Math.max(noticeLabel.implicitHeight, closeButton.implicitHeight) + Units.gu(2)
    height: visible ? implicitHeight : 0

    color: "#f4ecd0"
    border.color: "#c9b980"
    border.width: 1
    radius: Units.gu(0.6)

    Label {
        id: noticeLabel

        anchors.left: parent.left
        anchors.right: closeButton.left
        anchors.margins: Units.gu(1.5)
        anchors.verticalCenter: parent.verticalCenter

        wrapMode: Text.WordWrap
        color: "#5a4b16"
        font.pixelSize: FontUtils.sizeToPixels("small")
    }

    Button {
        id: closeButton

        anchors.right: parent.right
        anchors.rightMargin: Units.gu(1)
        anchors.verticalCenter: parent.verticalCenter
        width: Units.gu(5)

        text: "✕"
        flat: true
        LuneOSButton.textColor: "#5a4b16"

        onClicked: notice.dismissed()
    }
}

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
 * The settings apps' CategoryHeader: the light toolbar with the app's icon and
 * its bold title, the page's action on the right. A Back key comes in front
 * once a page has been pushed - the gesture area does the same, but a tablet
 * in a stand is often driven without it.
 */
Pane {
    id: root

    property string title
    property string icon: "../icon.png"
    property bool showBack: false
    property alias actionComponent: actionLoader.sourceComponent

    signal backClicked()

    padding: 0

    background: Image {
        source: "images/toolbar-light.png"
        fillMode: Image.Stretch
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Units.gu(1)
        anchors.right: actionLoader.left
        height: parent.height
        spacing: Units.gu(1)

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBack
            text: "Back"
            LuneOSButton.mainColor: LuneOSButton.secondaryColor

            onClicked: root.backClicked()
        }

        Image {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Units.gu(1)
            width: height
            source: root.icon
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("large")
            font.weight: Font.Bold
        }
    }

    Loader {
        id: actionLoader

        anchors.right: parent.right
        anchors.rightMargin: Units.gu(1.5)
        anchors.verticalCenter: parent.verticalCenter
    }
}

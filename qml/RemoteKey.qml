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

import "js/ButtonMap.js" as ButtonMap

/*
 * One key of a remote. It sends on press rather than on release, as a real
 * remote does, and with repeat set a held key keeps sending - volume and
 * channel need that, a power key must not have it.
 */
Button {
    id: key

    // The database entry: ["Power", "NEC", address, command] or a raw one
    property var button: null
    property bool repeat: false
    // Overrides the label from the button's own name
    property string caption: ""
    property color keyColour: "transparent"

    visible: button !== null
    text: caption !== "" ? caption : (button ? ButtonMap.label(button[0]) : "")
    font.pixelSize: FontUtils.sizeToPixels("medium")

    LuneOSButton.mainColor: keyColour.a > 0 ? keyColour : LuneOSButton.secondaryColor
    // White on the coloured keys, dark on the plain light ones, as the
    // theme's own secondary buttons have it
    LuneOSButton.textColor: keyColour.a > 0 && keyColour.hslLightness < 0.65 ? "white" : "#2b2b2b"

    onPressed: {
        if (button !== null) {
            appWindow.transmit(button, true);
            repeatTimer.interval = 450;
            repeatTimer.running = repeat;
        }
    }

    onReleased: repeatTimer.running = false
    onCanceled: repeatTimer.running = false

    Timer {
        id: repeatTimer

        repeat: true

        onTriggered: {
            interval = 160;

            // Only once the last burst is out: the service queues, and a
            // queue is exactly what makes volume keep climbing after release
            if (appWindow.pendingTransmits === 0)
                appWindow.transmit(key.button, false);
        }
    }
}

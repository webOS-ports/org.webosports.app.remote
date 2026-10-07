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
import "js/Store.js" as Store

/*
 * A remote, laid out from whatever keys its database file has.
 *
 * There is no hand-made layout per model - there are two thousand of them.
 * Instead the keys are sorted into the slots a physical remote has (power,
 * volume, arrows, transport, digits, colour keys) and each block shows only
 * if the file filled it. The category's layout decides what leads: a TV puts
 * volume and channel either side of the arrows, a fan its speed, a light its
 * brightness. Every key that fits no slot is still there, in the grid at the
 * bottom, under the name its contributor gave it.
 */
BasePage {
    id: page

    property var remote
    property string file
    property string layout: "generic"
    property string remoteName
    property bool saved: true
    property int remoteId: -1

    title: remoteName
    explanation: saved ? "" : "Try a few keys. If the device answers, Save keeps this remote; if not, go back and try the next model."

    readonly property var sorted: ButtonMap.classify(remote ? remote.buttons : [])
    readonly property var slots: sorted.slots

    readonly property real columnWidth: Math.min(width - Units.gu(2), Units.gu(60))
    // Four keys to a row inside a group's padding
    readonly property real keyWidth: (columnWidth - Units.gu(7)) / 4
    // The Q25's square has little height: lower keys and rockers there
    readonly property real keyHeight: appWindow.shortScreen ? Units.gu(3.5) : Units.gu(6)
    // The LuneOS GroupBox's own padding and spacing (12 and 6), halved where
    // the screen is short - on the Q25 that is the row the page was missing
    // A short screen has width to spare beside the pad and the number pad:
    // the menu keys go right of the arrows, the colour keys right of the digits
    readonly property bool sideMenu: appWindow.shortScreen && !stackedNavigation && menuKeys.length > 0
    readonly property bool sideColours: appWindow.shortScreen && hasDigits && colourKeys.length > 0

    readonly property real groupPadding: appWindow.shortScreen ? 6 : 12
    readonly property real groupSpacing: appWindow.shortScreen ? 3 : 6
    readonly property real rockerKeySize: appWindow.shortScreen ? Units.gu(5.5) : Units.gu(8)
    // Rocker, pad and rocker side by side want about this much width. Below
    // it, on a portrait phone, the pad gets a row of its own and the rockers go
    // under it; a square or landscape screen (the Q25) has the width but not
    // the height for that, and keeps them side by side with a smaller pad.
    readonly property bool stackedNavigation: columnWidth < Units.gu(52) && height > width

    // Rocker pairs in the order this kind of device wants them
    readonly property var rockers: {
        var all = {
            "vol":    { "label": "VOL",    "up": slots.volUp,    "down": slots.volDown },
            "ch":     { "label": "CH",     "up": slots.chUp,     "down": slots.chDown },
            "temp":   { "label": "TEMP",   "up": slots.tempUp,   "down": slots.tempDown },
            "speed":  { "label": "SPEED",  "up": slots.speedUp,  "down": slots.speedDown },
            "bright": { "label": "BRIGHT", "up": slots.brightUp, "down": slots.brightDown }
        };
        var order = {
            "climate": ["temp", "speed", "vol", "ch", "bright"],
            "fan":     ["speed", "temp", "vol", "ch", "bright"],
            "light":   ["bright", "speed", "vol", "ch", "temp"]
        }[layout] || ["vol", "ch", "temp", "speed", "bright"];

        return order.map(function(id) { return all[id]; }).filter(function(r) {
            return r.up !== undefined || r.down !== undefined;
        });
    }

    function present(names) {
        return names.map(function(n) { return slots[n]; }).filter(function(b) { return b !== undefined; });
    }

    headerAction: page.saved ? null : saveAction

    Component {
        id: saveAction

        Button {
            text: "Save"
            LuneOSButton.mainColor: LuneOSButton.affirmativeColor

            onClicked: {
                var id = Store.add(page.remoteName, page.file, page.remote.category,
                                   page.layout, page.remote.brand, page.remote.model);

                // Back to the list with the new remote on top of it, rather
                // than leaving the picking steps underneath it
                pageStack.pop(null);
                pageStack.push(Qt.resolvedUrl("RemotePage.qml"), {
                    "remote": page.remote, "file": page.file, "layout": page.layout,
                    "remoteName": page.remoteName, "saved": true, "remoteId": id
                });
            }
        }
    }

    readonly property var menuKeys: present(["back", "home", "menu", "info", "exit", "guide"])
    readonly property var transportKeys: present(["rewind", "play", "pause", "stop", "forward",
                                                  "prev", "next", "record", "eject"])
    readonly property var colourKeys: present(["red", "green", "yellow", "blue"])
    readonly property bool hasDigits: present(["digit1", "digit2", "digit3", "digit0"]).length > 0
    readonly property bool hasPad: slots.up !== undefined || slots.down !== undefined ||
                                   slots.left !== undefined || slots.right !== undefined
    readonly property bool hasPowerRow: present(["power", "powerOn", "powerOff", "source", "mute", "shutter"]).length > 0

    // Which page of keys is showing
    property alias keyPage: pages.currentIndex

    readonly property bool hasMediaPage: transportKeys.length > 0 || colourKeys.length > 0 || hasDigits
    readonly property bool hasMorePage: sorted.rest.length > 0

    /*
     * The keys on pages flicked sideways, the way Messwerk pages its sensors,
     * rather than one long column to scroll down: what a remote is used for
     * most - power, volume, the arrows - is all on the first, and a small
     * screen does not have to scroll to reach it. Each page still scrolls on
     * its own when a remote has more keys than it can show.
     */
    SwipeView {
        id: pages

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: indicator.top
        clip: true

        // A remote without media keys or extra keys has no use for their page
        Component.onCompleted: {
            if (!page.hasMorePage)
                removeItem(morePage);
            if (!page.hasMediaPage)
                removeItem(mediaPage);
        }

        // Power, volume, channel and the arrows
        Flickable {
            id: controlPage

            contentWidth: width
            contentHeight: controlColumn.height + Units.gu(2)
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: controlColumn

                width: page.columnWidth
                x: (parent.width - width) / 2
                y: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)
                spacing: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.hasPowerRow
                    title: "Power"

                    Column {
                        width: parent.width
                        spacing: Units.gu(1)

                        Flow {
                            width: parent.width
                            spacing: Units.gu(1)

                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: page.slots.power || null
                                caption: "Power"
                                keyColour: LuneOSButton.negativeColor
                            }
                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: page.slots.powerOn || null
                                caption: "On"
                                keyColour: LuneOSButton.affirmativeColor
                            }
                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: page.slots.powerOff || null
                                caption: "Off"
                                keyColour: LuneOSButton.negativeColor
                            }
                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: page.slots.source || null
                                caption: "Input"
                            }
                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: page.slots.mute || null
                                caption: "Mute"
                            }
                        }

                        // A camera remote is mostly the one key
                        RemoteKey {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.6; height: page.keyHeight * 2
                            button: page.slots.shutter || null
                            caption: "Shutter"
                            keyColour: LuneOSButton.negativeColor
                            font.pixelSize: FontUtils.sizeToPixels("x-large")
                        }
                    }
                }

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.hasPad || page.rockers.length > 0 || page.menuKeys.length > 0
                    title: "Navigation"

                    Column {
                        width: parent.width
                        spacing: appWindow.shortScreen ? Units.gu(1) : Units.gu(2)

                        // Rockers either side of the arrow pad, the way a TV remote
                        // has volume and channel; with no pad they sit side by side
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: appWindow.shortScreen ? Units.gu(1.5) : Units.gu(3)
                            visible: !page.stackedNavigation && (page.hasPad || page.rockers.length > 0)

                            Rocker {
                                keySize: page.rockerKeySize
                                readonly property var r: page.rockers.length > 0 ? page.rockers[0] : null
                                anchors.verticalCenter: parent.verticalCenter
                                label: r ? r.label : ""
                                upButton: r ? (r.up || null) : null
                                downButton: r ? (r.down || null) : null
                            }

                            DPad {
                                anchors.verticalCenter: parent.verticalCenter
                                slots: page.slots
                                size: Math.max(Units.gu(15), Math.min(appWindow.shortScreen ? Units.gu(17) : Units.gu(26),
                                                                  page.columnWidth - Units.gu(26)))
                            }

                            Repeater {
                                model: page.rockers.slice(1)

                                Rocker {
                                    keySize: page.rockerKeySize
                                    anchors.verticalCenter: parent.verticalCenter
                                    label: modelData.label
                                    upButton: modelData.up || null
                                    downButton: modelData.down || null
                                }
                            }

                            // The menu keys, right of the pad where the screen is short
                            Grid {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: page.sideMenu
                                columns: page.menuKeys.length > 4 ? 2 : 1
                                spacing: Units.gu(0.5)

                                Repeater {
                                    model: page.sideMenu ? page.menuKeys : []

                                    RemoteKey {
                                        width: page.menuKeys.length > 4 ? page.keyWidth * 0.75 : page.keyWidth
                                        height: page.keyHeight
                                        button: modelData
                                        font.pixelSize: FontUtils.sizeToPixels("small")
                                    }
                                }
                            }
                        }

                        // The same on a narrow screen: the pad as wide as it can
                        // usefully be, the rockers side by side beneath it
                        DPad {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: page.stackedNavigation && page.hasPad
                            slots: page.slots
                            size: Math.min(Units.gu(22), page.columnWidth - Units.gu(4))
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Units.gu(3)
                            visible: page.stackedNavigation && page.rockers.length > 0

                            Repeater {
                                model: page.stackedNavigation ? page.rockers : []

                                Rocker {
                                    // Two of these side by side across a phone's width
                                    keySize: Units.gu(6)
                                    horizontal: true
                                    label: modelData.label
                                    upButton: modelData.up || null
                                    downButton: modelData.down || null
                                }
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: Units.gu(1)
                            visible: !page.sideMenu

                            Repeater {
                                model: page.sideMenu ? [] : page.menuKeys

                                RemoteKey {
                                    width: page.keyWidth; height: page.keyHeight
                                    button: modelData
                                }
                            }
                        }
                    }
                }

            }
        }

        // Playback, the number pad and the colour keys under it, as on a TV remote
        Flickable {
            id: mediaPage

            contentWidth: width
            contentHeight: mediaColumn.height + Units.gu(2)
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: mediaColumn

                width: page.columnWidth
                x: (parent.width - width) / 2
                y: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)
                spacing: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.transportKeys.length > 0
                    title: "Playback"

                    Flow {
                        width: parent.width
                        spacing: Units.gu(1)

                        Repeater {
                            model: page.transportKeys

                            RemoteKey {
                                // Words, not symbols: the system font draws the
                                // play and skip triangles as emoji
                                readonly property var words: ({
                                    "rewind": "Rewind", "play": "Play", "pause": "Pause", "stop": "Stop",
                                    "forward": "Forward", "prev": "Previous", "next": "Next",
                                    "record": "Record", "eject": "Eject"
                                })
                                readonly property string slot: {
                                    for (var s in page.slots) {
                                        if (page.slots[s] === modelData)
                                            return s;
                                    }
                                    return "";
                                }

                                width: page.keyWidth; height: page.keyHeight
                                button: modelData
                                // play_pause is a toggle, and its own name says so
                                caption: slot === "play" && ButtonMap.normalise(modelData[0]) !== "play"
                                         ? "" : (words[slot] || "")
                                keyColour: slot === "record" ? LuneOSButton.negativeColor : "transparent"
                            }
                        }
                    }
                }

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.hasDigits
                    title: "Numbers"

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Units.gu(2)

                        // Digits as a phone-style pad
                        Grid {
                            columns: 3
                            spacing: Units.gu(1)

                            Repeater {
                                model: ["digit1", "digit2", "digit3", "digit4", "digit5", "digit6",
                                        "digit7", "digit8", "digit9", "", "digit0", ""]

                                Item {
                                    width: page.keyWidth; height: page.keyHeight

                                    RemoteKey {
                                        anchors.fill: parent
                                        button: modelData !== "" ? (page.slots[modelData] || null) : null
                                        font.pixelSize: FontUtils.sizeToPixels("large")
                                    }
                                }
                            }
                        }

                        // The colour keys, right of the digits where the screen is short
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.sideColours
                            spacing: Units.gu(0.5)

                            Repeater {
                                model: page.sideColours ? page.colourKeys : []

                                RemoteKey {
                                    width: page.keyWidth * 0.8
                                    height: page.keyHeight * 0.75
                                    button: modelData
                                    caption: " "
                                    keyColour: ButtonMap.colourFor(modelData[0])
                                }
                            }
                        }
                    }
                }

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.colourKeys.length > 0 && !page.sideColours
                    title: "Colour keys"

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Units.gu(1)

                        Repeater {
                            model: page.colourKeys

                            RemoteKey {
                                width: page.keyWidth * 0.8; height: page.keyHeight * 0.6
                                button: modelData
                                caption: " "
                                keyColour: ButtonMap.colourFor(modelData[0])
                            }
                        }
                    }
                }

            }
        }

        // Every key that fits no slot
        Flickable {
            id: morePage

            contentWidth: width
            contentHeight: moreColumn.height + Units.gu(2)
            flickableDirection: Flickable.VerticalFlick
            clip: true

            Column {
                id: moreColumn

                width: page.columnWidth
                x: (parent.width - width) / 2
                y: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)
                spacing: appWindow.shortScreen ? Units.gu(0.5) : Units.gu(1)

                GroupBox {
                    width: parent.width
                    padding: page.groupPadding
                    spacing: page.groupSpacing
                    visible: page.sorted.rest.length > 0
                    title: "More keys"

                    // Everything else, in the file's own order
                    Flow {
                        width: parent.width
                        spacing: Units.gu(1)

                        Repeater {
                            model: page.sorted.rest

                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: modelData
                                keyColour: ButtonMap.colourFor(modelData[0]) || "transparent"
                                font.pixelSize: FontUtils.sizeToPixels(text.length > 9 ? "small" : "medium")
                            }
                        }
                    }
                }
            }
        }
    }

    PageIndicator {
        id: indicator

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: pages.count > 1
        height: visible ? implicitHeight : 0

        count: pages.count
        currentIndex: pages.currentIndex
        interactive: true

        onCurrentIndexChanged: pages.currentIndex = currentIndex
    }
}

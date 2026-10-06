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
    readonly property real keyHeight: Units.gu(6)

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

    // The column of groups, capped and centred like the settings pages
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.height + Units.gu(2)
        clip: true

        Column {
            id: body

            width: page.columnWidth
            x: (parent.width - width) / 2
            y: Units.gu(1)
            spacing: Units.gu(1)

            GroupBox {
                width: parent.width
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
                visible: page.hasPad || page.rockers.length > 0 || page.menuKeys.length > 0
                title: "Navigation"

                Column {
                    width: parent.width
                    spacing: Units.gu(2)

                    // Rockers either side of the arrow pad, the way a TV remote
                    // has volume and channel; with no pad they sit side by side
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Units.gu(3)
                        visible: page.hasPad || page.rockers.length > 0

                        Rocker {
                            readonly property var r: page.rockers.length > 0 ? page.rockers[0] : null
                            anchors.verticalCenter: parent.verticalCenter
                            label: r ? r.label : ""
                            upButton: r ? (r.up || null) : null
                            downButton: r ? (r.down || null) : null
                        }

                        DPad {
                            anchors.verticalCenter: parent.verticalCenter
                            slots: page.slots
                            size: Math.min(Units.gu(26), page.columnWidth - Units.gu(26))
                        }

                        Repeater {
                            model: page.rockers.slice(1)

                            Rocker {
                                anchors.verticalCenter: parent.verticalCenter
                                label: modelData.label
                                upButton: modelData.up || null
                                downButton: modelData.down || null
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Units.gu(1)

                        Repeater {
                            model: page.menuKeys

                            RemoteKey {
                                width: page.keyWidth; height: page.keyHeight
                                button: modelData
                            }
                        }
                    }
                }
            }

            GroupBox {
                width: parent.width
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
                visible: page.colourKeys.length > 0
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

            GroupBox {
                width: parent.width
                visible: page.hasDigits
                title: "Numbers"

                // Digits as a phone-style pad
                Grid {
                    anchors.horizontalCenter: parent.horizontalCenter
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
            }

            GroupBox {
                width: parent.width
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

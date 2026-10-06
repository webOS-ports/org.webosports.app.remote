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

import QtQuick 2.12
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

// ListDelegateSeparator, PromptDialog, ConfirmDialog
import LuneOS.Components 1.0

import "Common"
import "js/Store.js" as Store

/*
 * The remotes the user has set up, laid out like the Wi-Fi page: one group
 * with the list, "Add Remote" at its foot the way Wi-Fi has "Join Network",
 * and touch-and-hold for rename and remove.
 */
BasePage {
    id: page

    title: "Remote"
    explanation: remotes.length > 0
                 ? "Point the top of the tablet at the device. Touch and hold a remote to rename or remove it."
                 : "Add one for your TV, sound bar, projector, fan, air conditioner or light strip, and this tablet becomes its remote."

    property var remotes: []

    function reload() {
        remotes = Store.list();
    }

    function open(remote) {
        appWindow.loadJson("r/" + remote.file + ".json", function(data) {
            pageStack.push(Qt.resolvedUrl("RemotePage.qml"), {
                "remote": data, "file": remote.file, "layout": remote.layout,
                "remoteName": remote.name, "saved": true, "remoteId": remote.id
            });
        }, function(error) {
            appWindow.irError = "The codes for " + remote.name + " are no longer in the database.";
        });
    }

    function addRemote() {
        pageStack.push(Qt.resolvedUrl("CategoriesPage.qml"));
    }

    Component.onCompleted: reload()
    // Coming back from adding one
    StackView.onActivated: reload()

    GroupBox {
        anchors.fill: parent
        anchors.margins: Units.gu(1)

        title: "My remotes"

        ColumnLayout {
            anchors.fill: parent

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: page.remotes

                delegate: ItemDelegate {
                    width: list.width
                    height: Units.gu(6)

                    RowLayout {
                        anchors.fill: parent

                        Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        Label {
                            text: modelData.category.replace(/_/g, " ")
                            color: "#555"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }

                    ListDelegateSeparator {
                        anchors.fill: parent
                        index: model.index
                        count: list.count
                    }

                    // A TapHandler, not a MouseArea: inside a ListView only a
                    // pointer handler keeps a long press (see the Wi-Fi page)
                    TapHandler {
                        id: rowTap

                        property bool held: false

                        longPressThreshold: 0.8
                        onPressedChanged: if (pressed) rowTap.held = false

                        onLongPressed: {
                            rowTap.held = true;
                            remoteMenu.remote = modelData;
                            remoteMenu.popup();
                        }

                        onTapped: if (!rowTap.held) page.open(modelData)
                    }
                }

                Label {
                    // Declared in the list, which would put it in the content
                    // item; centre it on the list itself instead
                    parent: list
                    anchors.centerIn: list
                    visible: list.count === 0
                    text: "No remotes yet."
                    color: "#555"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Units.gu(5)

                Image {
                    source: "images/icon-new.png"
                    Layout.preferredHeight: Units.gu(3.2)
                    Layout.preferredWidth: Units.gu(3.2)
                    fillMode: Image.PreserveAspectCrop
                    verticalAlignment: Image.AlignTop
                }

                Label {
                    Layout.fillWidth: true
                    text: "Add Remote"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                TapHandler {
                    onTapped: page.addRemote()
                }
            }
        }
    }

    Menu {
        id: remoteMenu

        property var remote: null

        MenuItem {
            text: "Rename"
            onTriggered: renameDialog.visible = true
        }
        MenuItem {
            text: "Remove"
            onTriggered: removeDialog.visible = true
        }
    }

    PromptDialog {
        id: renameDialog

        visible: false
        title: "Rename remote"
        defaultValue: remoteMenu.remote ? remoteMenu.remote.name : ""

        onAccepted: function(text) {
            if (text.trim() !== "") {
                Store.rename(remoteMenu.remote.id, text.trim());
                page.reload();
            }
            visible = false;
        }
        onRejected: visible = false
    }

    ConfirmDialog {
        id: removeDialog

        visible: false
        title: "Remove remote"
        message: remoteMenu.remote ? "Remove " + remoteMenu.remote.name + "?" : ""

        onAccepted: {
            Store.remove(remoteMenu.remote.id);
            page.reload();
            visible = false;
        }
        onRejected: visible = false
    }
}

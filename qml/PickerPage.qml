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
// ListDelegateSeparator
import LuneOS.Components 1.0

/*
 * A searchable list in one titled group, which is what each step of adding a
 * remote is: pick a kind of device, then a brand, then a model. items is an
 * array of { title, subtitle, ... }; whatever else an item carries comes back
 * in itemClicked untouched. The subtitle sits on the right, where the
 * settings apps put a row's value.
 *
 * With tryLabel set, each row also gets a button that sends a harmless key
 * from that remote, so finding which of a brand's code sets the device
 * answers to is a matter of going down the list.
 */
BasePage {
    id: picker

    property string groupTitle
    property var items: []
    property bool loading: false
    property string emptyText: "Nothing here."
    property string tryLabel: ""

    signal itemClicked(var item)
    signal tryClicked(var item)

    readonly property var filteredItems: {
        var needle = searchField.text.toLowerCase();

        if (needle === "")
            return items;

        return items.filter(function(item) {
            return item.title.toLowerCase().indexOf(needle) >= 0;
        });
    }

    GroupBox {
        anchors.fill: parent
        anchors.margins: Units.gu(1)

        title: picker.groupTitle

        ColumnLayout {
            anchors.fill: parent

            TextField {
                id: searchField

                Layout.fillWidth: true
                // A short list is quicker to scan than to search
                visible: picker.items.length > 12
                placeholderText: "Search"
                inputMethodHints: Qt.ImhNoPredictiveText
            }

            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: picker.filteredItems

                delegate: ItemDelegate {
                    width: list.width
                    height: Units.gu(6)

                    RowLayout {
                        anchors.fill: parent
                        spacing: Units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }

                        Label {
                            visible: text !== ""
                            text: modelData.subtitle || ""
                            color: "#555"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        Button {
                            visible: picker.tryLabel !== ""
                            text: picker.tryLabel
                            LuneOSButton.mainColor: LuneOSButton.secondaryColor
                            onClicked: picker.tryClicked(modelData)
                        }
                    }

                    ListDelegateSeparator {
                        anchors.fill: parent
                        index: model.index
                        count: list.count
                    }

                    onClicked: picker.itemClicked(modelData)
                }

                Label {
                    // Declared in the list, which would put it in the content
                    // item; centre it on the list itself instead
                    parent: list
                    anchors.centerIn: list
                    width: list.width - Units.gu(4)
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: picker.loading ? "Loading..." : picker.emptyText
                    color: "#555"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }
    }
}

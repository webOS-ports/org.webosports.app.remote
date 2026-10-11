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

// Units & font sizes
import LunaNext.Common 0.1
import LuneOS.Forms 1.0

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
AppPage {
    id: picker

    property string groupTitle
    property var items: []
    property bool loading: false
    property string emptyText: "Nothing here."
    property string tryLabel: ""

    signal itemClicked(var item)
    signal tryClicked(var item)

    GroupBox {
        anchors.fill: parent
        anchors.margins: Units.gu(1)

        title: picker.groupTitle

        // The search box, the empty and loading lines and the Try buttons are
        // LuneOS.Forms' ListPicker; items are { title, subtitle, ... } and
        // come back whole
        ListPicker {
            anchors.fill: parent

            entries: picker.items
            loading: picker.loading
            emptyText: picker.emptyText
            actionText: picker.tryLabel

            onPicked: (key, entry) => picker.itemClicked(entry)
            onActionClicked: (entry) => picker.tryClicked(entry)
        }
    }
}

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

import "js/ButtonMap.js" as ButtonMap

/*
 * Adding a remote, step three: the model. Brands reuse code sets across years
 * of models, so the exact model is often not listed; "Try" on each row sends
 * a harmless key from that remote, and the first one the device answers to is
 * the one to pick.
 */
PickerPage {
    id: page

    property var category
    property var brand

    // The remote files loaded so far for Try, by file, so trying a row twice
    // does not read it twice
    property var _cache: ({})

    title: brand.name + " " + category.title
    groupTitle: "Choose a model"
    tryLabel: "Try"
    explanation: "Point the tablet at your " + category.title.replace(/s$/, "") +
          " and press Try on a row: it sends " + testKeyName() + ". Pick the first one that works."

    items: brand.models.map(function(model) {
        return {
            "title": model[0],
            "subtitle": model[2] + (model[2] === 1 ? " key" : " keys"),
            "file": model[1]
        };
    })

    // Mute toggles back with a second press and power can be switched back
    // on; which one leads depends on what the device has
    function testKeyName() {
        return (category.layout === "tv" || category.layout === "media" || category.layout === "audio")
               ? "Mute (or Power)" : "Power";
    }

    function pickTestButton(buttons) {
        var sorted = ButtonMap.classify(buttons).slots;
        var order = (category.layout === "tv" || category.layout === "media" || category.layout === "audio")
                    ? ["mute", "power", "volUp"] : ["power", "powerOn", "powerOff", "shutter"];

        for (var i = 0; i < order.length; i++) {
            if (sorted[order[i]] !== undefined)
                return sorted[order[i]];
        }

        return buttons.length > 0 ? buttons[0] : null;
    }

    function withRemote(file, callback) {
        if (_cache[file] !== undefined) {
            callback(_cache[file]);
            return;
        }

        appWindow.loadJson("r/" + file + ".json", function(remote) {
            _cache[file] = remote;
            callback(remote);
        });
    }

    onTryClicked: function(item) {
        withRemote(item.file, function(remote) {
            var button = pickTestButton(remote.buttons);

            if (button !== null)
                appWindow.transmit(button, true);
        });
    }

    onItemClicked: function(item) {
        withRemote(item.file, function(remote) {
            pageStack.push(Qt.resolvedUrl("RemotePage.qml"), {
                "remote": remote,
                "file": item.file,
                "layout": page.category.layout,
                "remoteName": page.brand.name + " " + item.title,
                "saved": false
            });
        });
    }
}

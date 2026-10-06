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

/* Adding a remote, step two: the brand */
PickerPage {
    id: page

    property var category

    title: category.title
    groupTitle: "Choose a brand"
    loading: true

    Component.onCompleted: {
        appWindow.loadJson(category.id + ".json", function(brands) {
            page.items = brands.map(function(brand) {
                return {
                    "title": brand.name,
                    "subtitle": brand.models.length + (brand.models.length === 1 ? " remote" : " remotes"),
                    "brand": brand
                };
            });
            page.loading = false;
        }, function(error) {
            page.loading = false;
        });
    }

    onItemClicked: function(item) {
        pageStack.push(Qt.resolvedUrl("ModelsPage.qml"), {"category": page.category, "brand": item.brand});
    }
}

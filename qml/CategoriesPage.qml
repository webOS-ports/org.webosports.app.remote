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

/*
 * Adding a remote, step one: what kind of device. The categories with the
 * most remotes come first - they are what most people are looking for - and
 * the search field finds the rest.
 */
PickerPage {
    id: page

    title: "Add Remote"
    groupTitle: "Choose a kind of device"
    explanation: "Not sure? Most TV remotes are under TVs; a remote for lights or LED strips is under LED Lighting."
    loading: true
    emptyText: "The remote database is missing from this install."

    Component.onCompleted: {
        appWindow.loadJson("index.json", function(index) {
            index.sort(function(a, b) { return b.models - a.models; });
            page.items = index.map(function(category) {
                return {
                    "title": category.title,
                    "subtitle": category.brands + (category.brands === 1 ? " brand, " : " brands, ") +
                                category.models + (category.models === 1 ? " remote" : " remotes"),
                    "category": category
                };
            });
            page.loading = false;
        }, function(error) {
            page.loading = false;
        });
    }

    onItemClicked: function(item) {
        pageStack.push(Qt.resolvedUrl("BrandsPage.qml"), {"category": item.category});
    }
}

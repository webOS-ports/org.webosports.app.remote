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

import QtQuick
import QtQuick.Controls
import QtTest

import "../../qml/js/Store.js" as Store

/*
 * The app itself - qml/main.qml and its remotes page - on the build host,
 * with luneos-components' desktop stand-ins for the bus and the window.
 * Touch and hold a remote, pick Rename or Remove, answer the dialog. Run by
 * tests/run-qml-tests.sh; each state is saved to build/test-output/ui.
 */
TestCase {
    id: test
    name: "RemoteUi"
    when: windowShown

    property var app: null
    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))

    function shot(name) {
        var done = false;
        waitForRendering(app.contentItem);
        var ok = app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + name + ".png");
            done = true;
        });
        verify(ok, "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    function init() {
        var remotes = Store.list();
        for (var i = 0; i < remotes.length; i++)
            Store.remove(remotes[i].id);
        Store.add("Living room TV", "tv/Samsung/UE40", "TVs", "tv", "Samsung", "UE40");
        Store.add("Bedroom fan", "fans/Dyson/AM07", "Fans", "fan", "Dyson", "AM07");

        var component = Qt.createComponent(Qt.resolvedUrl("../../qml/main.qml"));
        if (component.status !== Component.Ready)
            fail(component.errorString());
        app = component.createObject(null, { width: 720, height: 720 });
        verify(app !== null, "main.qml did not load");
        tryVerify(function() { return page() && page().remotes && page().remotes.length === 2; }, 5000,
                  "the remotes page lists the two remotes");
        waitForRendering(app.contentItem);
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
    }

    function page() {
        return app.pageStack.currentItem;
    }

    function find(item, test) {
        if (!item)
            return null;
        if (test(item))
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = find(kids[i], test);
            if (found)
                return found;
        }
        return null;
    }

    function byName(objectName) {
        return find(app.contentItem, function(i) { return i.objectName === objectName && i.visible; });
    }

    function shown(item) {
        for (var i = item; i; i = i.parent) {
            if (!i.visible)
                return false;
        }
        return true;
    }

    function labelFor(text) {
        return find(app.contentItem, function(i) { return i.text === text && i instanceof Label && shown(i); });
    }

    function dialog(kind) {
        // The dialog is the item holding the named button, a few levels up
        var button = byName(kind === "prompt" ? "promptAcceptButton" : "confirmAcceptButton");
        for (var i = button; i; i = i.parent) {
            if (i.hasOwnProperty("dialogHeight"))
                return i;
        }
        return null;
    }

    // Touch and hold a remote's row, then the menu's entry
    function hold(remoteName, entry) {
        var row = labelFor(remoteName);
        verify(row, "a row for " + remoteName);
        mousePress(row, row.width / 2, row.height / 2);
        wait(1200);
        mouseRelease(row, row.width / 2, row.height / 2);
        var item = null;
        tryVerify(function() {
            item = find(app.contentItem, function(i) { return i instanceof MenuItem && i.text === entry && shown(i); });
            return item !== null;
        }, 3000, "the menu has " + entry);
        waitForRendering(app.contentItem);
        mouseClick(item);
        tryVerify(function() {
            return find(app.contentItem, function(i) { return i instanceof Menu && i.opened; }) === null;
        }, 3000, "the menu closes");
    }

    function tap(objectName) {
        var button = byName(objectName);
        verify(button, objectName);
        verify(shown(button), objectName + " is shown");
        mouseClick(button);
    }

    // Types into the prompt's field as the keyboard would, over what it holds
    function typeName(text) {
        var field = byName("promptField");
        tryVerify(function() { return field.textInput.activeFocus; }, 3000, "the field has the focus");
        field.textInput.selectAll();
        for (var i = 0; i < text.length; i++)
            keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i));
        compare(field.text, text);
    }

    function names() {
        return Store.list().map(function(r) { return r.name; });
    }

    function test_0_list() {
        verify(labelFor("Living room TV"));
        verify(labelFor("Bedroom fan"));
        shot("remotes");
    }

    function test_rename() {
        hold("Living room TV", "Rename");
        var d = dialog("prompt");
        verify(d && d.visible, "the rename dialog is open");
        compare(d.title, "Rename remote");
        var field = byName("promptField");
        compare(field.text, "Living room TV");
        compare(byName("promptAcceptButton").text, "OK");
        compare(byName("promptRejectButton").text, "Cancel");
        shot("rename");

        typeName("  Lounge TV ");
        tap("promptAcceptButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");
        compare(names(), ["Lounge TV", "Bedroom fan"]);
        tryVerify(function() { return labelFor("Lounge TV") !== null; }, 3000, "the list shows the new name");
        shot("renamed");
    }

    function test_rename_cancel() {
        hold("Living room TV", "Rename");
        var d = dialog("prompt");
        typeName("Something else");
        tap("promptRejectButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");
        compare(names(), ["Living room TV", "Bedroom fan"]);
    }

    // An empty name is not taken, and the dialog closes as for Cancel
    function test_rename_empty() {
        hold("Bedroom fan", "Rename");
        var d = dialog("prompt");
        typeName("   ");
        tap("promptAcceptButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");
        compare(names(), ["Living room TV", "Bedroom fan"]);
    }

    // The field starts with the name of the remote held this time, not with
    // what was typed for another
    function test_rename_second_remote() {
        hold("Living room TV", "Rename");
        var d = dialog("prompt");
        typeName("Typed and cancelled");
        tap("promptRejectButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");

        hold("Bedroom fan", "Rename");
        verify(dialog("prompt").visible);
        compare(byName("promptField").text, "Bedroom fan");
        tap("promptAcceptButton");
        compare(names(), ["Living room TV", "Bedroom fan"]);
    }

    // Nor with what was typed and cancelled for the same remote before
    function test_rename_same_remote_again() {
        hold("Living room TV", "Rename");
        var d = dialog("prompt");
        typeName("Typed and cancelled");
        tap("promptRejectButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");

        hold("Living room TV", "Rename");
        verify(dialog("prompt").visible);
        compare(names(), ["Living room TV", "Bedroom fan"]);
        compare(byName("promptField").text, "Living room TV");
    }

    function test_remove() {
        hold("Bedroom fan", "Remove");
        var d = dialog("confirm");
        verify(d && d.visible, "the remove dialog is open");
        compare(d.title, "Remove remote");
        compare(d.message, "Remove Bedroom fan?");
        compare(byName("confirmAcceptButton").text, "OK");
        compare(byName("confirmRejectButton").text, "Cancel");
        shot("remove");

        tap("confirmAcceptButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");
        compare(names(), ["Living room TV"]);
        tryVerify(function() { return labelFor("Bedroom fan") === null; }, 3000, "the row goes");
        shot("removed");
    }

    function test_remove_cancel() {
        hold("Living room TV", "Remove");
        var d = dialog("confirm");
        compare(d.message, "Remove Living room TV?");
        tap("confirmRejectButton");
        tryVerify(function() { return !d.visible; }, 3000, "the dialog closes");
        compare(names(), ["Living room TV", "Bedroom fan"]);
    }
}

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

import LunaNext.Common 0.1

import "../../qml/js/Store.js" as Store

/*
 * Every screen of the app on one device's screen per run - the window is
 * the profile's display, with its grid unit (see tests/run-qml-tests.sh,
 * which runs this once per profile in PROFILES): the remotes, empty and
 * not, with the hold menu, Rename and Remove; the notices; adding one -
 * kinds, brands, models, the remote on trial - and a saved remote of each
 * layout, every page of its keys. The codes are tests/data/irdb, a few
 * remotes of the database tools/build-irdb.py makes.
 *
 * Each screen is checked for what breaks a layout - shown, not empty,
 * inside the window, no page wider than the window, no two keys on top of
 * each other - and saved as build/test-output/ui/<profile>-<screen>.png,
 * with the panel's notch and rounded corners painted over it (PanelShape).
 */
TestCase {
    id: test
    name: "RemoteScreens"
    when: windowShown

    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    readonly property string profile: Settings.profileName
    property var app: null

    // A remote of each layout in tests/data/irdb, mostly the one with the
    // most keys
    readonly property var layouts: [
        { layout: "tv", category: "TVs", file: "TVs/134", brand: "LG", model: "MKJ39170828 Service" },
        { layout: "media", category: "Blu-Ray", file: "Blu-Ray/11", brand: "Blu-Ray", model: "UD7007 (RC006UD)" },
        { layout: "audio", category: "Audio_and_Video_Receivers", file: "Audio_and_Video_Receivers/64", brand: "Receiver",
          model: "XXD3105" },
        { layout: "climate", category: "ACs", file: "ACs/21", brand: "AC", model: "CS-21H3A-B155AF" },
        { layout: "fan", category: "Fans", file: "Fans/101", brand: "Fan", model: "FV-30BG1x" },
        { layout: "light", category: "LED_Lighting", file: "LED_Lighting/2", brand: "Airivo", model: "NorthernLights" },
        // 256 keys, numbered 1 to 256, and nothing else
        { layout: "light", category: "LED_Lighting", file: "LED_Lighting/137", brand: "LED", model: "LEDStrip", shot: "light-numbered" },
        { layout: "camera", category: "Cameras", file: "Cameras/21", brand: "Camera", model: "NDI HX PTZOptics NDI HX CAM1" },
        { layout: "generic", category: "Bidet", file: "Bidet/2", brand: "Bidet", model: "bb2000" }
    ]

    Component {
        id: panelShape
        PanelShape {}
    }

    // A warning from the app's own QML (a TypeError in a binding, a binding
    // loop) fails the test it shows in: the climate and fan remotes logged
    // TypeErrors for a page their remote had no use for.
    function init() {
        failOnWarning(new RegExp(Qt.resolvedUrl("../../qml/").toString().replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
    }

    function init_data() {
        return [{ tag: profile + " " + Settings.displayWidth + "x" + Settings.displayHeight }];
    }

    function clearRemotes() {
        var remotes = Store.list();
        for (var i = 0; i < remotes.length; i++)
            Store.remove(remotes[i].id);
    }

    function startApp(remotes) {
        clearRemotes();
        for (var i = 0; i < remotes.length; i++)
            Store.add(remotes[i].name, remotes[i].file, remotes[i].category, remotes[i].layout,
                      remotes[i].brand, remotes[i].model);
        var component = Qt.createComponent(Qt.resolvedUrl("../../qml/main.qml"));
        if (component.status !== Component.Ready)
            fail(component.errorString());
        app = component.createObject(null, { databaseUrl: Qt.resolvedUrl("../data/irdb/") });
        verify(app !== null, "main.qml did not load");
        compare(app.width, Settings.displayWidth);
        compare(app.height, Settings.displayHeight);
        tryVerify(function() { return page() && page().remotes && page().remotes.length === remotes.length; }, 5000,
                  "the remotes page lists " + remotes.length + " remotes");
        waitForRendering(app.contentItem);
        return app;
    }

    function twoRemotes() {
        return [{ name: "Living room TV", file: "TVs/134", category: "TVs", layout: "tv", brand: "LG",
                  model: "MKJ39170828 Service" },
                { name: "Bedroom fan", file: "Fans/101", category: "Fans", layout: "fan", brand: "Fan", model: "FV-30BG1x" }];
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        clearRemotes();
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

    function findAll(item, test, into) {
        if (!item)
            return into;
        if (test(item))
            into.push(item);
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++)
            findAll(kids[i], test, into);
        return into;
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

    // Shown, not empty and inside the window, left to right; top to bottom
    // too unless it may be scrolled to.
    function onScreen(item, label, scrolls) {
        verify(item, "no " + label);
        verify(shown(item), label + " hidden");
        verify(item.width > 0 && item.height > 0, label + " has no size: " + item.width + "x" + item.height);
        var p = item.mapToItem(null, 0, 0);
        verify(p.x >= -0.5 && p.x + item.width <= app.width + 0.5,
               label + " off the side: x " + p.x + ", width " + item.width + " of " + app.width);
        if (!scrolls)
            verify(p.y >= -0.5 && p.y + item.height <= app.height + 0.5,
                   label + " runs off the bottom: y " + p.y + ", height " + item.height + " of " + app.height);
    }

    // The notice under the header, starting with text: shown, inside the
    // window, its text not cut off
    function noticeShowing(text) {
        var t = null;
        tryVerify(function() {
            t = find(app.contentItem, function(i) {
                return i instanceof Text && typeof i.text === "string" && i.text.indexOf(text) === 0 && shown(i);
            });
            return t !== null;
        }, 3000, "a notice saying " + text);
        waitForRendering(app.contentItem);
        onScreen(t, "the notice's text");
        verify(!t.truncated, "the notice's text cut off");
        return t;
    }

    function shot(name) {
        wait(300);
        waitForRendering(app.contentItem);
        var shape = panelShape.createObject(app.contentItem);
        if (shape.shaped) {
            shape.requestPaint();
            tryVerify(function() { return shape.done; }, 3000, "panel shape painted");
            waitForRendering(app.contentItem);
        }
        var done = false;
        verify(app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + profile + "-" + name + ".png");
            done = true;
        }), "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
        shape.destroy();
    }

    function settle() {
        tryCompare(app.pageStack, "busy", false);
        waitForRendering(app.contentItem);
    }

    // The page's main box (the GroupBox every list page is in) fills the
    // window below the header and stays inside it.
    function groupFits(title) {
        var box = find(page(), function(i) { return i instanceof GroupBox && i.title === title; });
        onScreen(box, "the " + title + " box");
        verify(box.height > Units.gu(10), "the " + title + " box has no room: " + box.height);
        return box;
    }

    // Touch and hold a remote's row: its menu
    function hold(remoteName) {
        var row = labelFor(remoteName);
        verify(row, "a row for " + remoteName);
        mousePress(row, row.width / 2, row.height / 2);
        wait(1200);
        mouseRelease(row, row.width / 2, row.height / 2);
        // The menu is a popup, in the window's overlay: its entries show it
        menuEntry("Rename");
        waitForRendering(app.contentItem);
    }

    function menuEntry(text) {
        var item = null;
        tryVerify(function() {
            item = find(app.contentItem, function(i) { return i instanceof MenuItem && i.text === text && shown(i); });
            return item !== null;
        }, 3000, "the menu has " + text);
        return item;
    }

    // The dialog holding the named button
    function dialogOf(buttonName) {
        var button = find(app.contentItem, function(i) { return i.objectName === buttonName && shown(i); });
        verify(button, buttonName);
        for (var i = button; i; i = i.parent) {
            if (i.hasOwnProperty("dialogHeight"))
                return i;
        }
        return null;
    }

    function dialogFits(buttons, label) {
        var d = dialogOf(buttons[0]);
        verify(d, label);
        tryVerify(function() { return d.opacity === 1; }, 3000, label + " shown");
        for (var i = 0; i < buttons.length; i++)
            onScreen(find(d, function(it) { return it.objectName === buttons[i]; }), label + ": " + buttons[i]);
        return d;
    }

    // The remote's current page of keys, once it has slid into place
    function keyPage() {
        var pages = find(page(), function(i) { return i instanceof SwipeView; });
        verify(pages, "no key pages");
        var current = pages.currentItem;
        tryVerify(function() { return Math.abs(current.mapToItem(null, 0, 0).x - pages.mapToItem(null, 0, 0).x) < 1; },
                  3000, "the key page in place");
        return current;
    }

    // Every key on the remote's current page: shown ones not empty, inside
    // the window left to right, none over another, its name not cut off
    // where it could be made smaller, and the extra keys across the whole
    // width of their box. Returns how many there are.
    function keysFit(label) {
        var current = keyPage();
        var keys = findAll(current.contentItem, function(i) {
            return i instanceof Button && i.hasOwnProperty("button") && i.hasOwnProperty("caption") && shown(i);
        }, []);
        var off = [], cut = [];
        var boxes = [];
        for (var k = 0; k < keys.length; k++) {
            var key = keys[k];
            var name = label + " key " + (key.text || k);
            verify(key.width > 0 && key.height > 0, name + " has no size: " + key.width + "x" + key.height);
            var w = key.mapToItem(null, 0, 0);
            if (w.x < -0.5 || w.x + key.width > app.width + 0.5)
                off.push(name + " at x " + Math.round(w.x));
            // A name is cut off only once it is as small as a key's text
            // may be: the style's label, one line, cut them off at full size
            var t = key.contentItem.item || key.contentItem;
            if (t.truncated && t.fontInfo.pixelSize > t.minimumPixelSize + 0.5)
                cut.push(name + " at " + t.fontInfo.pixelSize + " px");
            var p = key.mapToItem(current.contentItem, 0, 0);
            boxes.push({ x: p.x, y: p.y, w: key.width, h: key.height, name: name });
        }
        var over = [];
        for (var a = 0; a < boxes.length; a++) {
            for (var b = a + 1; b < boxes.length; b++) {
                var A = boxes[a], B = boxes[b];
                var dx = Math.min(A.x + A.w, B.x + B.w) - Math.max(A.x, B.x);
                var dy = Math.min(A.y + A.h, B.y + B.h) - Math.max(A.y, B.y);
                if (dx > 1 && dy > 1)
                    over.push(A.name + " over " + B.name + " by " + Math.min(dx, dy).toFixed(1));
            }
        }
        verify(off.length === 0, "off the side: " + off.join(", "));
        verify(over.length === 0, "on top of each other: " + over.join(", "));
        verify(cut.length === 0, "names cut off at a size they could shrink from: " + cut.join(", "));
        var more = find(current.contentItem, function(i) { return i instanceof GroupBox && i.title === "More keys" && shown(i); });
        // All of More keys in one text size
        if (more) {
            var sizes = {};
            findAll(more.contentItem, function(i) { return keys.indexOf(i) >= 0; }, []).forEach(function(k) {
                var lt = k.contentItem.item || k.contentItem;
                sizes[lt.fontInfo.pixelSize] = (sizes[lt.fontInfo.pixelSize] || 0) + 1;
            });
            verify(Object.keys(sizes).length <= 1, label + ": More keys in several sizes: " + JSON.stringify(sizes));
        }
        // A full row of them, that is: four
        var inMore = more ? findAll(more.contentItem, function(i) { return keys.indexOf(i) >= 0; }, []) : [];
        if (inMore.length >= 4) {
            var right = 0;
            for (k = 0; k < inMore.length; k++)
                right = Math.max(right, inMore[k].mapToItem(more.contentItem, inMore[k].width, 0).x);
            verify(Math.abs(right - more.contentItem.width) <= 1,
                   label + ": the extra keys end at " + right.toFixed(1) + " of the box's " + more.contentItem.width);
        }
        // contentWidth is the page's own width: what is in it must fit that
        var r = current.contentItem.childrenRect;
        verify(r.x >= -0.5 && r.x + r.width <= current.width + 0.5,
               label + " wider than the window: " + r.x + " + " + r.width + " of " + current.width);
        return keys.length;
    }

    // Each page of the remote's keys, saved, then checked; the pages that
    // came out without a key, by number
    function shootRemote(name) {
        var pages = find(page(), function(i) { return i instanceof SwipeView; });
        var empty = [];
        for (var i = 0; i < pages.count; i++) {
            pages.currentIndex = i;
            keyPage();
            shot(name + (i === 0 ? "" : "-" + (i + 1)));
        }
        for (i = 0; i < pages.count; i++) {
            pages.currentIndex = i;
            if (keysFit(name + " page " + (i + 1)) === 0)
                empty.push(i + 1);
        }
        pages.currentIndex = 0;
        return empty;
    }

    function test_remotes_empty() {
        startApp([]);
        groupFits("My remotes");
        onScreen(labelFor("No remotes yet."), "the empty line");
        onScreen(labelFor("Add Remote"), "Add Remote");
        shot("remotes-empty");
    }

    function test_remotes() {
        startApp(twoRemotes());
        groupFits("My remotes");
        onScreen(labelFor("Living room TV"), "the first remote");
        onScreen(labelFor("Bedroom fan"), "the second remote");
        onScreen(labelFor("Add Remote"), "Add Remote");
        shot("remotes");

        hold("Living room TV");
        onScreen(menuEntry("Rename"), "Rename");
        onScreen(menuEntry("Remove"), "Remove");
        shot("remote-menu");
        mouseClick(menuEntry("Rename"));
        dialogFits(["promptAcceptButton", "promptRejectButton", "promptField"], "the rename dialog");
        shot("rename");
        mouseClick(find(app.contentItem, function(i) { return i.objectName === "promptRejectButton" && shown(i); }));

        hold("Bedroom fan");
        mouseClick(menuEntry("Remove"));
        dialogFits(["confirmAcceptButton", "confirmRejectButton"], "the remove dialog");
        shot("remove");
    }

    function test_no_transmitter() {
        startApp(twoRemotes());
        app.irChecked = true;
        app.irAvailable = false;
        var notice = noticeShowing("No infrared transmitter was found");
        groupFits("My remotes");
        var box = find(page(), function(i) { return i instanceof GroupBox; });
        verify(box.mapToItem(null, 0, 0).y >= notice.mapToItem(null, 0, notice.height).y - 0.5, "the list under the notice");
        onScreen(labelFor("Living room TV"), "the first remote under the notice");
        shot("no-transmitter");
    }

    function test_add_a_remote() {
        startApp([]);
        mouseClick(labelFor("Add Remote"));
        settle();
        tryVerify(function() { return page().items && page().items.length === 8 && !page().loading; }, 5000,
                  "the kinds of device listed");
        groupFits("Choose a kind of device");
        onScreen(labelFor("TVs"), "TVs");
        shot("categories");

        page().itemClicked(page().items.filter(function(it) { return it.category.id === "TVs"; })[0]);
        settle();
        tryVerify(function() { return page().items.length > 0 && !page().loading; }, 5000, "the brands listed");
        groupFits("Choose a brand");
        onScreen(labelFor("LG"), "LG");
        shot("brands");

        page().itemClicked(page().items.filter(function(it) { return it.title === "LG"; })[0]);
        settle();
        groupFits("Choose a model");
        onScreen(labelFor("24LJ4840"), "a model");
        var tries = findAll(page(), function(i) { return i instanceof Button && i.text === "Try" && shown(i); }, []);
        verify(tries.length === page().items.length, "a Try for each model: " + tries.length);
        for (var t = 0; t < tries.length; t++)
            onScreen(tries[t], "Try " + t, true);
        shot("models");

        page().itemClicked(page().items.filter(function(it) { return it.file === "TVs/134"; })[0]);
        settle();
        tryVerify(function() { return page().remoteName === "LG MKJ39170828 Service"; }, 5000, "the remote on trial");
        verify(!page().saved);
        onScreen(find(app.contentItem, function(i) { return i instanceof Button && i.text === "Save" && shown(i); }), "Save");
        keyPage();
        shot("remote-trial");
        verify(keysFit("the remote on trial") > 0, "no keys on the remote on trial");
    }

    function test_remotes_by_layout_data() {
        return layouts.map(function(l) {
            return { tag: profile + " " + (l.shot || l.layout), shot: l.shot || l.layout,
                     layout: l.layout, category: l.category, file: l.file,
                     brand: l.brand, model: l.model };
        });
    }

    function test_remotes_by_layout(data) {
        var name = data.brand + " " + data.layout;
        startApp([{ name: name, file: data.file, category: data.category, layout: data.layout, brand: data.brand,
                    model: data.model }]);
        page().open(page().remotes[0]);
        settle();
        tryVerify(function() { return page().remoteName === name; }, 5000, "the " + data.layout + " remote opens");
        verify(page().saved);
        compare(shootRemote("remote-" + data.shot), [], "pages without a key");
    }

    function test_send_failed() {
        startApp(twoRemotes());
        page().open(page().remotes[0]);
        settle();
        app.irError = "The infrared service did not answer.";
        waitForRendering(app.contentItem);
        var notice = noticeShowing("The infrared service did not answer.");
        var pages = find(page(), function(i) { return i instanceof SwipeView; });
        verify(pages.mapToItem(null, 0, 0).y >= notice.mapToItem(null, 0, notice.height).y - 0.5, "the keys under the notice");
        keyPage();
        shot("send-failed");
        verify(keysFit("the remote under a notice") > 0, "no keys under the notice");
    }
}

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

// LS2 access
import LuneOS.Service 1.0
// Units & font sizes
import LunaNext.Common 0.1
import LuneOS.Forms 1.0

import "js/IrEncoder.js" as IrEncoder

/*
 * Remote: a universal remote for devices with an infrared transmitter.
 *
 * The codes come from Flipper-IRDB (CC0), converted at build time into the
 * JSON under irdb/ by tools/build-irdb.py. The app turns a button into timings
 * itself (js/IrEncoder.js) and hands those to org.webosports.service.ir, which
 * owns the transmitter.
 */
AppWindow {
    id: appWindow

    title: "Remote"
    icon: Qt.resolvedUrl("../icon.png")
    initialPage: Qt.resolvedUrl("RemotesPage.qml")
    // A tablet in a stand is often driven without the gesture area
    showBack: true
    // Less header still on a short screen than AppWindow's default gives
    headerHeight: shortScreen ? Units.gu(5)
                : (height < Units.gu(70) || width < Units.gu(50)) ? Units.gu(7.5)
                : Units.gu(10)

    // Mirrors org.webosports.service.ir/getStatus
    property bool irAvailable: false
    // False until the service has answered at all, so the page does not flash
    // "no transmitter" while it is still being asked
    property bool irChecked: false
    property string irError: ""

    // Bursts in flight. Held keys only send again once the last one is out,
    // so letting go of volume-up stops the volume, not a queue behind it.
    property int pendingTransmits: 0

    // The Q25's square and other screens with little height: smaller header,
    // keys and rockers, and no explanation lines under the content
    readonly property bool shortScreen: height < Units.gu(60)

    // RC5 and RC6 carry a toggle bit that flips on every new press, which is
    // how the receiver tells a second press from a held key
    property bool toggleBit: false

    readonly property string databaseUrl: Qt.resolvedUrl("../irdb/")

    LunaService {
        id: irService

        name: "org.webosports.app.remote"
        usePrivateBus: true

        onInitialized: appWindow.subscribeStatus()
    }

    function subscribeStatus() {
        irService.subscribe("luna://org.webosports.service.ir/getStatus",
                            JSON.stringify({"subscribe": true}),
                            function(message) {
                                var response = JSON.parse(message.payload);
                                irChecked = true;
                                irAvailable = response.returnValue === true && response.available === true;
                            },
                            function(error) {
                                irChecked = true;
                                irAvailable = false;
                            });
    }

    /*
     * Loads one of the database's JSON files. XMLHttpRequest on file:// is
     * allowed on LuneOS (QML_XHR_ALLOW_FILE_READ in webos-global.conf), and it
     * keeps the multi-megabyte database out of the QML engine until a page
     * actually needs a part of it.
     */
    function loadJson(path, onLoaded, onFailed) {
        var xhr = new XMLHttpRequest();

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            var data = null;

            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {
                data = null;
            }

            if (data !== null)
                onLoaded(data);
            else if (onFailed)
                onFailed("Could not read " + path);
        };
        xhr.open("GET", databaseUrl + path);
        xhr.send();
    }

    /*
     * Sends one database button: ["Power", "NEC", address, command] or
     * ["Power", "raw", frequency, dutyCycle, [us, ...]]. newPress is false for
     * the auto-repeat of a held key, which must keep the RC5/RC6 toggle bit.
     * Returns false when the button was not sent.
     */
    function transmit(button, newPress) {
        var encoded;

        if (newPress)
            toggleBit = !toggleBit;

        if (button[1] === "raw")
            encoded = IrEncoder.encodeRaw(button[2], button[3], button[4]);
        else
            encoded = IrEncoder.encodeParsed(button[1], button[2], button[3], {"toggle": toggleBit});

        if (encoded === null) {
            irError = "This key uses " + button[1] + ", which the app cannot send yet.";
            return false;
        }

        pendingTransmits++;
        irService.call("luna://org.webosports.service.ir/transmit",
                       JSON.stringify({"frequency": encoded.frequency, "pattern": encoded.pattern}),
                       function(message) {
                           var response = JSON.parse(message.payload);
                           pendingTransmits--;
                           irError = response.returnValue ? "" : (response.errorText || "Sending failed");
                       },
                       function(error) {
                           pendingTransmits--;
                           irError = "The infrared service did not answer.";
                       });
        return true;
    }

    // Between the header and the pages: AppWindow stacks what is declared
    // inside here
    Item {
        width: appWindow.width
        height: statusNotice.visible ? statusNotice.height + Units.gu(2) : 0

        StatusNotice {
            id: statusNotice

            x: Units.gu(1)
            y: Units.gu(1)
            width: parent.width - Units.gu(2)

            visible: text !== ""
            text: appWindow.irChecked && !appWindow.irAvailable
                  ? "No infrared transmitter was found on this device, or org.webosports.service.ir is not running. Remotes can be set up, but keys will not send."
                  : appWindow.irError
            onDismissed: appWindow.irError = ""
        }
    }
}

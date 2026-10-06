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

import "Common"

/*
 * What every page of the app is built on, after the settings apps' BasePage:
 * the same grey gradient behind the content, and the italic explanation line
 * under it that the legacy apps used for "what does this do" and "touch and
 * hold for more".
 */
Page {
    id: basePage

    // Shown on the right of the header, where the settings apps have their switch
    property Component headerAction: null
    property alias explanation: footerText.text

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#D8D8D8" }
            GradientStop { position: 1.0; color: "#888" }
        }
    }

    footer: ExplanationText {
        id: footerText

        visible: text !== ""
        leftPadding: 4
        rightPadding: 4
        bottomPadding: 4
        font.italic: true
    }
}

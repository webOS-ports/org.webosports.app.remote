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

.pragma library

/*
 * Finds the keys a remote layout cares about among the buttons of a database
 * file.
 *
 * Flipper-IRDB has no fixed vocabulary - every contributor names keys their
 * own way ("Vol_up", "vol+", "VOLUME UP", "Volume_Up") - so each slot lists
 * the spellings that actually occur, taken from a count over the whole
 * database. A key that matches no slot is not lost: it goes into the "more"
 * grid under its own name.
 */

var SLOTS = {
    power:     ["power", "power_toggle", "on_off", "onoff", "standby", "pwr", "power_on_off"],
    powerOn:   ["power_on", "on", "pwr_on"],
    powerOff:  ["power_off", "off", "pwr_off"],
    mute:      ["mute", "muting", "mute_toggle"],
    volUp:     ["vol_up", "vol+", "volume_up", "vol_plus", "volup", "volume+", "vol_+", "v+"],
    volDown:   ["vol_dn", "vol-", "volume_down", "vol_down", "vol_minus", "voldown", "volume-", "vol_-", "v-"],
    chUp:      ["ch_next", "ch+", "ch_up", "channel_up", "chan_up", "prog+", "p+", "ch_plus", "page_up"],
    chDown:    ["ch_prev", "ch-", "ch_down", "channel_down", "chan_down", "prog-", "p-", "ch_minus", "page_down"],
    up:        ["up", "arrow_up", "cursor_up", "nav_up", "dpad_up"],
    down:      ["down", "arrow_down", "cursor_down", "nav_down", "dpad_down"],
    left:      ["left", "arrow_left", "cursor_left", "nav_left", "dpad_left"],
    right:     ["right", "arrow_right", "cursor_right", "nav_right", "dpad_right"],
    ok:        ["ok", "enter", "select", "center", "confirm"],
    back:      ["back", "return", "ret", "previous_menu"],
    exit:      ["exit", "esc"],
    home:      ["home", "smart_hub", "smart", "my_apps"],
    menu:      ["menu", "settings", "setup", "tools", "options", "option", "q_menu"],
    info:      ["info", "display", "osd", "status"],
    source:    ["source", "input", "av", "tv/av", "input_source", "inputs"],
    guide:     ["guide", "epg", "tv_guide"],
    play:      ["play", "play_pause", "play/pause", "playpause"],
    pause:     ["pause"],
    stop:      ["stop"],
    rewind:    ["rewind", "fast_ba", "rew", "fast_back", "fast_backward", "rwd", "backward"],
    forward:   ["fast_forward", "fast_fo", "ff", "fwd", "forward", "fastforward"],
    prev:      ["prev", "previous", "skip_back", "skip_prev", "track_prev"],
    next:      ["next", "skip_next", "skip_fwd", "track_next"],
    record:    ["record", "rec"],
    eject:     ["eject", "open_close", "open/close"],
    red:       ["red"],
    green:     ["green"],
    yellow:    ["yellow"],
    blue:      ["blue"],
    tempUp:    ["temp+", "temp_up", "temperature_up", "temp_plus", "heat_up"],
    tempDown:  ["temp-", "temp_down", "temperature_down", "temp_minus", "heat_down"],
    speedUp:   ["speed_up", "fan_up", "fan+", "faster", "speed+"],
    speedDown: ["speed_down", "fan_down", "fan-", "slower", "speed-"],
    brightUp:  ["bright_up", "brighter", "brightness_up", "brightness+", "bright+"],
    brightDown:["bright_down", "darker", "brightness_down", "brightness-", "bright-", "dim"],
    shutter:   ["shutter", "photo", "capture", "release", "shoot"]
};

var DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

// "VOLUME UP" and "Volume-Up" both become "volume_up"
function normalise(name) {
    return String(name).toLowerCase().replace(/^\s+|\s+$/g, "").replace(/[\s\-]+(?=[a-z0-9])/g, "_");
}

var _lookup = null;

function _buildLookup() {
    _lookup = {};

    for (var slot in SLOTS) {
        for (var i = 0; i < SLOTS[slot].length; i++)
            _lookup[SLOTS[slot][i]] = slot;
    }

    for (var d = 0; d < DIGITS.length; d++)
        _lookup[DIGITS[d]] = "digit" + DIGITS[d];
}

/*
 * Sorts a remote's buttons into slots. Returns { slots: {slot: button}, rest:
 * [button, ...] }, where rest keeps the file's own order - contributors tend
 * to list keys the way the physical remote has them, which beats any order we
 * could invent. The first button to claim a slot keeps it; a later duplicate
 * spelling stays reachable in rest.
 */
function classify(buttons) {
    if (_lookup === null)
        _buildLookup();

    var slots = {};
    var rest = [];

    for (var i = 0; i < buttons.length; i++) {
        var slot = _lookup[normalise(buttons[i][0])];

        if (slot !== undefined && slots[slot] === undefined)
            slots[slot] = buttons[i];
        else
            rest.push(buttons[i]);
    }

    // A file with only discrete on/off still deserves a big power key
    if (slots.power === undefined && slots.powerOn !== undefined && slots.powerOff === undefined) {
        slots.power = slots.powerOn;
        delete slots.powerOn;
    }

    return { slots: slots, rest: rest };
}

/* LED strip remotes are mostly colour keys; show them in their colour */
var COLOURS = {
    red: "#d9372b", green: "#3ba64b", blue: "#2f6fd6", white: "#f2f2f2",
    yellow: "#f2d230", orange: "#f28c28", pink: "#f27ab8", purple: "#8e44ad",
    cyan: "#2ac3d6", violet: "#7f3fbf", magenta: "#d63fa8", lime: "#9bd62f",
    warm_white: "#f6d9a8", cold_white: "#e3f0ff", cool_white: "#e3f0ff"
};

function colourFor(name) {
    var key = normalise(name);
    return COLOURS[key] !== undefined ? COLOURS[key] : "";
}

/* "Vol_up" -> "Vol up": the stored name is the label, minus the underscores */
function label(name) {
    return String(name).replace(/_/g, " ");
}

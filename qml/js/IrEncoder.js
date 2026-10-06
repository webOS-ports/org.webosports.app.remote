/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * Protocol timings and bit layouts are ported from the Flipper Zero firmware
 * (GPL-3.0, github.com/flipperdevices/flipperzero-firmware lib/infrared).
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
 * Turns Flipper-IRDB entries into the pattern the IR blaster takes:
 * "carrierHz,mark_us,space_us,mark_us,...".
 *
 * The goal is to put on the air exactly what a Flipper Zero does for one
 * press of a saved button, because that is what the IRDB codes were captured
 * and checked against. So the encoders below are not written from protocol
 * specs; they follow Flipper's encoder state machines step by step, quirks
 * included (RC5X never sets its field bit, the Pioneer frame ends in a space,
 * the first NEC repeat gap depends on the frame length, ...). The test
 * harness in claude-scratch/IR/encoder-test compiles Flipper's own C
 * encoders and diffs them against this file.
 *
 * What one pattern contains: Flipper's infrared_send() keeps pulling timings
 * until the encoder has reported "done" MAX(min repeat count, 1) times, so a
 * pattern is the frame followed by whatever repeats that implies:
 *   - NEC/NECext/NEC42/NEC42ext, Samsung32, RC5/RC5X, RC6, Kaseikyo, RCA:
 *     minimum is 1, so just the frame.
 *   - SIRC/SIRC15/SIRC20: minimum 3, three full frames, each started 45 ms
 *     after the previous one (Sony receivers ignore a single frame).
 *   - Pioneer: minimum 2, two full frames 26 ms apart.
 * options.repeats asks for more transmissions, as holding the button on the
 * Flipper would; NEC and Samsung then send their short repeat codes rather
 * than the full frame again, the others resend the frame.
 *
 * Shaping: Flipper starts every message with a silence and emits Manchester
 * codes as half-bits, so its raw output has leading spaces and runs of the
 * same level. Here same-level runs are merged into one duration, and leading
 * and trailing spaces are dropped, since the kernel wants a strict
 * mark/space alternation that begins and ends with a mark.
 */

var DUTY = 0.33;

// Timing sets, in microseconds, named as in the Flipper *_i.h headers.
var NEC_T = { pm: 9000, ps: 4500, m1: 560, s1: 1690, m0: 560, s0: 560 };
var SAMSUNG_T = { pm: 4500, ps: 4500, m1: 550, s1: 1650, m0: 550, s0: 550 };
var KASEIKYO_T = { pm: 3456, ps: 1728, m1: 432, s1: 1296, m0: 432, s0: 432 };
var RCA_T = { pm: 4000, ps: 4000, m1: 500, s1: 2000, m0: 500, s0: 1000 };
var PIONEER_T = { pm: 8500, ps: 4225, m1: 500, s1: 1500, m0: 500, s0: 500 };
var SIRC_T = { pm: 2400, ps: 600, m1: 1200, s1: 600, m0: 600, s0: 600 };
var RC5_T = { pm: 0, ps: 0, half: 888 };
var RC6_T = { pm: 2666, ps: 889, half: 444 };

var PROTOCOLS = {
    "NEC":       { freq: 38000, addrBits: 8,  cmdBits: 8,  minRepeats: 1 },
    "NECext":    { freq: 38000, addrBits: 16, cmdBits: 16, minRepeats: 1 },
    "NEC42":     { freq: 38000, addrBits: 13, cmdBits: 8,  minRepeats: 1 },
    "NEC42ext":  { freq: 38000, addrBits: 26, cmdBits: 16, minRepeats: 1 },
    "Samsung32": { freq: 38000, addrBits: 8,  cmdBits: 8,  minRepeats: 1 },
    "RC5":       { freq: 36000, addrBits: 5,  cmdBits: 6,  minRepeats: 1 },
    "RC5X":      { freq: 36000, addrBits: 5,  cmdBits: 7,  minRepeats: 1 },
    "RC6":       { freq: 36000, addrBits: 8,  cmdBits: 8,  minRepeats: 1 },
    "SIRC":      { freq: 40000, addrBits: 5,  cmdBits: 7,  minRepeats: 3 },
    "SIRC15":    { freq: 40000, addrBits: 8,  cmdBits: 7,  minRepeats: 3 },
    "SIRC20":    { freq: 40000, addrBits: 13, cmdBits: 7,  minRepeats: 3 },
    "Kaseikyo":  { freq: 38000, addrBits: 26, cmdBits: 10, minRepeats: 1 },
    "RCA":       { freq: 38000, addrBits: 4,  cmdBits: 8,  minRepeats: 1 },
    "Pioneer":   { freq: 40000, addrBits: 8,  cmdBits: 8,  minRepeats: 2 }
};

var supportedProtocols = Object.keys(PROTOCOLS);

// ---- pulse train -----------------------------------------------------------

// Levels are kept beside the durations so that two spaces (or two marks) in
// a row collapse into one, exactly as they would on the LED.
function Train() {
    this.dur = [];
    this.lvl = [];
}

Train.prototype.put = function (level, us) {
    var n = this.dur.length;
    if (n > 0 && this.lvl[n - 1] === level)
        this.dur[n - 1] += us;
    else {
        this.dur.push(us);
        this.lvl.push(level);
    }
    return us;
};

Train.prototype.pattern = function () {
    var a = 0, b = this.dur.length;
    while (a < b && !this.lvl[a]) a++;
    while (b > a && !this.lvl[b - 1]) b--;
    return this.dur.slice(a, b);
};

// ---- bit helpers -----------------------------------------------------------

// Flipper packs payloads into a little-endian byte buffer and sends LSB first.
function wordsToBytes(words) {
    var bytes = [];
    for (var i = 0; i < words.length; i++)
        for (var k = 0; k < 4; k++)
            bytes.push((words[i] >>> (8 * k)) & 0xFF);
    return bytes;
}

function bitAt(bytes, i) {
    var b = bytes[i >> 3];
    return b === undefined ? 0 : (b >> (i & 7)) & 1;
}

function reverse8(v) {
    var r = 0;
    for (var i = 0; i < 8; i++)
        if (v & (1 << i)) r |= 1 << (7 - i);
    return r;
}

// ---- frame shapes ----------------------------------------------------------
// Each returns the sum of the durations it emitted; NEC and SIRC size their
// repeat gap from it.

// Pulse distance: constant mark, the space carries the bit. A closing stop
// mark follows the last bit, except for Pioneer whose frame ends on a space.
function pulseDistance(tr, t, bytes, nbits, stopMark) {
    var sum = tr.put(true, t.pm) + tr.put(false, t.ps);
    for (var i = 0; i < nbits; i++) {
        var v = bitAt(bytes, i);
        sum += tr.put(true, v ? t.m1 : t.m0);
        sum += tr.put(false, v ? t.s1 : t.s0);
    }
    if (stopMark)
        sum += tr.put(true, t.m1);
    return sum;
}

// Pulse width (Sony): the mark carries the bit and there is no space after
// the last one.
function pulseWidth(tr, t, bytes, nbits) {
    var sum = tr.put(true, t.pm) + tr.put(false, t.ps);
    for (var i = 0; i < nbits; i++) {
        var v = bitAt(bytes, i);
        sum += tr.put(true, v ? t.m1 : t.m0);
        if (i < nbits - 1)
            sum += tr.put(false, t.s1);
    }
    return sum;
}

// Manchester as Flipper does it: a 1 in the buffer is mark-then-space (RC5
// stores its bits inverted to get the opposite convention). The final
// half-bit is dropped when it would be a space. wideBit is RC6's toggle bit,
// which runs at twice the normal length.
function manchester(tr, t, bytes, nbits, wideBit) {
    if (t.pm) {
        tr.put(true, t.pm);
        tr.put(false, t.ps);
    }
    for (var i = 0; i < nbits; i++) {
        var v = bitAt(bytes, i) === 1;
        var h = (i === wideBit) ? 2 * t.half : t.half;
        tr.put(v, h);
        if (i === nbits - 1 && v)
            break;
        tr.put(!v, h);
    }
}

// ---- protocol encoders -----------------------------------------------------

function necPayload(protocol, a, c) {
    if (protocol === "NEC")
        return { bits: 32, bytes: wordsToBytes([
            (a & 0xFF) | ((~a & 0xFF) << 8) | ((c & 0xFF) << 16) | ((~c & 0xFF) << 24)]) };
    if (protocol === "NECext")
        return { bits: 32, bytes: wordsToBytes([(a & 0xFFFF) | ((c & 0xFFFF) << 16)]) };
    if (protocol === "NEC42")
        return { bits: 42, bytes: wordsToBytes([
            (a & 0x1FFF) | ((~a & 0x1FFF) << 13) | ((c & 0x3F) << 26),
            ((c & 0xC0) >> 6) | ((~c & 0xFF) << 2)]) };
    // NEC42ext
    return { bits: 42, bytes: wordsToBytes([
        (a & 0x3FFFFFF) | ((c & 0x3F) << 26),
        (c & 0xFFC0) >> 6]) };
}

function encodeNec(tr, protocol, a, c, sends) {
    var p = necPayload(protocol, a, c);
    var sum = pulseDistance(tr, NEC_T, p.bytes, p.bits, true);
    // Repeat code: 9 ms mark, 2.25 ms space, stop mark, on a 110 ms grid.
    // The first gap completes the main frame's 110 ms period.
    for (var r = 1; r < sends; r++) {
        tr.put(false, r === 1 ? 110000 - sum : 110000 - 9000 - 2250 - 560);
        tr.put(true, 9000);
        tr.put(false, 2250);
        tr.put(true, 560);
    }
}

function encodeSamsung(tr, a, c, sends) {
    a &= 0xFF;
    c &= 0xFF;
    var bytes = wordsToBytes([a | (a << 8) | (c << 16) | ((~c & 0xFF) << 24)]);
    pulseDistance(tr, SAMSUNG_T, bytes, 32, true);
    // Samsung's repeat code is a preamble plus a single 1 bit.
    for (var r = 1; r < sends; r++) {
        tr.put(false, r === 1 ? 46000 : 97000);
        tr.put(true, 4500);
        tr.put(false, 4500);
        tr.put(true, 550);
        tr.put(false, 1650);
        tr.put(true, 550);
    }
}

function encodeSirc(tr, protocol, a, c, sends) {
    var w, bits;
    if (protocol === "SIRC") {
        w = (c & 0x7F) | ((a & 0x1F) << 7);
        bits = 12;
    } else if (protocol === "SIRC15") {
        w = (c & 0x7F) | ((a & 0xFF) << 7);
        bits = 15;
    } else {
        w = (c & 0x7F) | ((a & 0x1FFF) << 7);
        bits = 20;
    }
    var bytes = wordsToBytes([w]);
    for (var r = 0; r < sends; r++) {
        var sum = pulseWidth(tr, SIRC_T, bytes, bits);
        // Frames start every 45 ms.
        if (r < sends - 1)
            tr.put(false, 45000 - sum);
    }
}

function encodePioneer(tr, a, c, sends) {
    // 32 data bits plus a trailing 0, whose space is where Flipper stops.
    var bytes = [a & 0xFF, ~a & 0xFF, c & 0xFF, ~c & 0xFF, 0];
    for (var r = 0; r < sends; r++) {
        if (r > 0)
            tr.put(false, 26000);
        pulseDistance(tr, PIONEER_T, bytes, 33, false);
    }
}

function rc5Bytes(protocol, a, c, toggle) {
    var w = 0x01;                   // start bit
    if (protocol === "RC5")
        w |= 0x02;                  // second start bit; RC5X leaves it clear
    if (toggle)
        w |= 0x04;
    w |= (reverse8(a & 0xFF) >> 3) << 3;    // 5 address bits, MSB first
    w |= (reverse8(c & 0xFF) >> 2) << 8;    // 6 command bits, MSB first
    var bytes = wordsToBytes([w]);
    bytes[0] = ~bytes[0] & 0xFF;
    bytes[1] = ~bytes[1] & 0xFF;
    return bytes;
}

function rc6Bytes(a, c, toggle) {
    // start bit, mode 000, toggle, 8 address and 8 command bits MSB first
    var w = 0x01 | (toggle ? 0x10 : 0) | (reverse8(a & 0xFF) << 5) | (reverse8(c & 0xFF) << 13);
    return wordsToBytes([w]);
}

function kaseikyoBytes(a, c) {
    var id = (a >>> 24) & 3;
    var vendor = (a >>> 8) & 0xFFFF;
    var genre1 = (a >>> 4) & 0xF;
    var genre2 = a & 0xF;
    c &= 0xFFFF;
    var d = [];
    d[0] = vendor & 0xFF;
    d[1] = vendor >> 8;
    var parity = d[0] ^ d[1];
    parity = (parity & 0xF) ^ (parity >> 4);
    d[2] = (parity & 0xF) | (genre1 << 4);
    d[3] = (genre2 & 0xF) | ((c & 0xF) << 4);
    d[4] = ((id << 6) | ((c >> 4) & 0xFF)) & 0xFF;
    d[5] = d[2] ^ d[3] ^ d[4];
    return d;
}

function rcaBytes(a, c) {
    a &= 0xFF;
    c &= 0xFF;
    return wordsToBytes([(a & 0xF) | (c << 4) | ((~a & 0xF) << 12) | ((~c & 0xFF) << 16)]);
}

// Protocols without a repeat code resend the whole frame after a fixed
// silence; Flipper puts that silence in front of every frame, including the
// first one, which is what the pattern() trim removes again.
function encodeResend(tr, silence, sends, frame) {
    for (var r = 0; r < sends; r++) {
        tr.put(false, silence);
        frame();
    }
}

// ---- public API ------------------------------------------------------------

/*
 * "04 00 00 00" -> 4. IRDB stores address and command as four little-endian
 * bytes. Parsed like Flipper's flipper_format does it: each of the first four
 * tokens contributes its first two hex digits, anything after that is
 * ignored. That matters for the handful of IRDB entries with typos such as
 * "13A 00 00 00", which a Flipper reads as 0x13. Returns null where Flipper
 * would fail to load the value.
 */
function parseHexBytes(text) {
    if (typeof text !== "string")
        return null;
    var parts = text.trim().split(/\s+/);
    if (parts.length < 4)
        return null;
    var v = 0;
    for (var i = 0; i < 4; i++) {
        if (!/^[0-9A-Fa-f]{2}/.test(parts[i]))
            return null;
        v += parseInt(parts[i].substring(0, 2), 16) * Math.pow(256, i);
    }
    return v >>> 0;
}

/*
 * Carrier, duty cycle, minimum repeats and field widths Flipper uses for a
 * protocol, or null if it is not one we know.
 */
function protocolInfo(protocol) {
    var p = PROTOCOLS[protocol];
    if (!p)
        return null;
    return { frequency: p.freq, dutyCycle: DUTY, minRepeats: p.minRepeats,
             addressBits: p.addrBits, commandBits: p.cmdBits };
}

/*
 * Encode a parsed IRDB entry. address and command are uint32 numbers (or the
 * IRDB hex-byte strings). options.toggle sets the RC5/RC6 toggle bit;
 * options.repeats asks for that many transmissions in total (never fewer
 * than the protocol's minimum).
 *
 * Returns { frequency, dutyCycle, pattern } or null for an unknown protocol
 * or an address/command wider than the protocol allows - Flipper refuses to
 * load such a signal, so there is no reference behaviour to copy.
 */
function encodeParsed(protocol, address, command, options) {
    var p = PROTOCOLS[protocol];
    if (!p)
        return null;
    options = options || {};

    var a = typeof address === "string" ? parseHexBytes(address) : address;
    var c = typeof command === "string" ? parseHexBytes(command) : command;
    if (typeof a !== "number" || typeof c !== "number" || a !== Math.floor(a) || c !== Math.floor(c))
        return null;
    if (a < 0 || a >= Math.pow(2, p.addrBits) || c < 0 || c >= Math.pow(2, p.cmdBits))
        return null;

    var sends = Math.max(p.minRepeats, options.repeats | 0, 1);
    var toggle = !!options.toggle;
    var tr = new Train();

    switch (protocol) {
    case "NEC":
    case "NECext":
    case "NEC42":
    case "NEC42ext":
        encodeNec(tr, protocol, a, c, sends);
        break;
    case "Samsung32":
        encodeSamsung(tr, a, c, sends);
        break;
    case "SIRC":
    case "SIRC15":
    case "SIRC20":
        encodeSirc(tr, protocol, a, c, sends);
        break;
    case "Pioneer":
        encodePioneer(tr, a, c, sends);
        break;
    case "RC5":
    case "RC5X":
        var b5 = rc5Bytes(protocol, a, c, toggle);
        encodeResend(tr, 27000, sends, function () { manchester(tr, RC5_T, b5, 14, -1); });
        break;
    case "RC6":
        var b6 = rc6Bytes(a, c, toggle);
        encodeResend(tr, 27000, sends, function () { manchester(tr, RC6_T, b6, 21, 4); });
        break;
    case "Kaseikyo":
        var bk = kaseikyoBytes(a, c);
        encodeResend(tr, 130000, sends, function () { pulseDistance(tr, KASEIKYO_T, bk, 48, true); });
        break;
    case "RCA":
        var br = rcaBytes(a, c);
        encodeResend(tr, 8000, sends, function () { pulseDistance(tr, RCA_T, br, 24, true); });
        break;
    default:
        return null;
    }

    return { frequency: p.freq, dutyCycle: DUTY, pattern: tr.pattern() };
}

/*
 * Encode a raw IRDB entry. data is the array of microseconds (or the
 * space-separated string from the file), starting with a mark. Values are
 * rounded to integers and anything below 1 becomes 1, because the kernel
 * rejects zero-length timings; a trailing space is dropped so the pattern
 * ends on a mark.
 */
function encodeRaw(frequency, dutyCycle, data) {
    if (typeof data === "string")
        data = data.trim().split(/\s+/);
    if (!data || !data.length)
        return null;
    var pattern = [];
    for (var i = 0; i < data.length; i++) {
        var v = Math.round(Number(data[i]));
        pattern.push(v >= 1 ? v : 1);
    }
    if (pattern.length % 2 === 0)
        pattern.pop();
    if (!pattern.length)
        return null;
    var f = Math.round(Number(frequency));
    var d = Number(dutyCycle);
    return { frequency: f > 0 ? f : 38000, dutyCycle: d > 0 && d <= 1 ? d : DUTY, pattern: pattern };
}

// "38000,9000,4500,..." for the blaster's sysfs/ioctl interface.
function toKernelString(encoded) {
    if (!encoded || !encoded.pattern || !encoded.pattern.length)
        return "";
    return [encoded.frequency].concat(encoded.pattern).join(",");
}

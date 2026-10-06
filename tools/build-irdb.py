#!/usr/bin/env python3
# Copyright (c) 2026 Herman van Hazendonk <github.com@herrie.org>
#
# SPDX-License-Identifier: GPL-3.0-only

"""
Turns a Flipper-IRDB checkout (github.com/Lucaslhm/Flipper-IRDB, CC0-1.0) into
the compact JSON the app reads at runtime:

  <out>/index.json            categories: id, title, layout, brand/model counts
  <out>/<category>.json       brands and their models, each pointing at a file
  <out>/r/<category>/<n>.json one remote: its buttons as compact arrays

A button is ["Power", "NEC", address, command] for a decoded code, or
["Power", "raw", frequency, dutyCycle, [us, us, ...]] for a captured one. The
app encodes decoded ones itself (js/IrEncoder.js), so the data stays small and
any protocol fix reaches every remote without regenerating anything.

_Converted_ is left out on purpose: it is bulk-converted from other databases
(irdb, IRPLUS) that carry their own licences, not CC0, and it is three times
the size of the rest put together.

Usage: build-irdb.py <Flipper-IRDB checkout> <output directory>
"""

import json
import os
import re
import shutil
import sys

SKIP_DIRS = {"_Converted_"}

# Which remote layout a category gets. Anything not listed is "generic": a
# power key and a grid of every button the file has.
LAYOUTS = {
    "TVs": "tv",
    "Monitors": "tv",
    "Projectors": "tv",
    "Touchscreen_Displays": "tv",
    "Digital_Signs": "tv",
    "Streaming_Devices": "media",
    "Cable_Boxes": "media",
    "DVB-T": "media",
    "TV_Tuner": "media",
    "Blu-Ray": "media",
    "DVD_Players": "media",
    "VCR": "media",
    "Laserdisc": "media",
    "Multimedia": "media",
    "Consoles": "media",
    "Computers": "media",
    "Audio_and_Video_Receivers": "audio",
    "SoundBars": "audio",
    "Speakers": "audio",
    "CD_Players": "audio",
    "MiniDisc": "audio",
    "Head_Units": "audio",
    "Car_Multimedia": "audio",
    "ACs": "climate",
    "Heaters": "climate",
    "Fireplaces": "climate",
    "Fans": "fan",
    "Air_Purifiers": "fan",
    "Humidifiers": "fan",
    "LED_Lighting": "light",
    "Cameras": "camera",
}


def parse_ir(path):
    """Yields the signals of a Flipper .ir file as dicts of its key: value lines."""
    signal = {}

    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()

            if line.startswith("#"):
                if signal:
                    yield signal
                signal = {}
                continue

            key, sep, value = line.partition(":")

            if not sep:
                continue

            key = key.strip().lower()

            # A new name without a "#" in between still starts a new signal
            if key == "name" and "name" in signal:
                yield signal
                signal = {}

            signal[key] = value.strip()

    if signal:
        yield signal


def le_bytes(text):
    """'04 00 00 00' -> 4: Flipper writes the 32-bit values as little-endian bytes.

    Read the way flipper_format does, so a file means here what it means on a
    Flipper: exactly four tokens, each taken by its first two hex digits (the
    database has the odd '13A 00 00 00'). Anything else raises ValueError and
    the key is dropped, as a Flipper drops it.
    """
    tokens = text.split()

    if len(tokens) != 4:
        raise ValueError(text)

    value = 0

    for i, byte in enumerate(tokens):
        value |= int(byte[:2], 16) << (8 * i)

    return value


def to_button(signal):
    name = signal.get("name", "").strip()
    kind = signal.get("type", "").strip().lower()

    if not name:
        return None

    try:
        if kind == "parsed":
            protocol = signal["protocol"].strip()
            command = le_bytes(signal["command"])

            # RC5 has six command bits; commands 0x40-0x7F are RC5X, which
            # spends the second start bit on the seventh. Contributors capture
            # them as RC5 all the same, and a Flipper then refuses them - but
            # the device they came from expects exactly the RC5X frame.
            if protocol == "RC5" and 0x40 <= command <= 0x7F:
                protocol = "RC5X"

            return [name, protocol, le_bytes(signal["address"]), command]

        if kind == "raw":
            data = [int(round(float(x))) for x in signal["data"].split()]

            if not data:
                return None

            return [name, "raw", int(float(signal.get("frequency", 38000))),
                    round(float(signal.get("duty_cycle", 0.33)), 3), data]
    except (KeyError, ValueError):
        return None

    return None


def tidy(text):
    return re.sub(r"\s+", " ", text.replace("_", " ")).strip()


def model_name(brand, rel_parts):
    """LG/LG_OLED65C8PUA.ir -> 'OLED65C8PUA'; Sony/Bravia/RM-ED009.ir -> 'Bravia RM-ED009'."""
    parts = list(rel_parts)
    parts[-1] = os.path.splitext(parts[-1])[0]
    name = " ".join(tidy(p) for p in parts)
    brand_words = tidy(brand)

    if name.lower().startswith(brand_words.lower() + " "):
        name = name[len(brand_words) + 1:]

    return name or brand_words


def main(src, out):
    if os.path.isdir(out):
        shutil.rmtree(out)

    os.makedirs(out)
    index = []

    for category in sorted(os.listdir(src)):
        cat_dir = os.path.join(src, category)

        if (category in SKIP_DIRS or category.startswith(".") or
                not os.path.isdir(cat_dir)):
            continue

        brands = {}
        n = 0

        for root, dirs, files in os.walk(cat_dir):
            dirs.sort()

            for fname in sorted(files):
                if not fname.lower().endswith(".ir"):
                    continue

                rel = os.path.relpath(os.path.join(root, fname), cat_dir).split(os.sep)
                # A file straight in the category has no brand folder
                brand = tidy(rel[0]) if len(rel) > 1 else "Other"
                model = model_name(rel[0] if len(rel) > 1 else "",
                                   rel[1:] if len(rel) > 1 else rel)

                buttons, seen = [], set()

                for signal in parse_ir(os.path.join(root, fname)):
                    button = to_button(signal)

                    # Files often list the same key twice (two captures of it);
                    # the first is the one the contributor tested
                    if button and button[0].lower() not in seen:
                        seen.add(button[0].lower())
                        buttons.append(button)

                if not buttons:
                    continue

                rid = "%s/%d" % (category, n)
                n += 1
                os.makedirs(os.path.join(out, "r", category), exist_ok=True)

                with open(os.path.join(out, "r", rid + ".json"), "w") as f:
                    json.dump({"category": category, "brand": brand, "model": model,
                               "buttons": buttons}, f, separators=(",", ":"))

                brands.setdefault(brand, []).append([model, rid, len(buttons)])

        if not brands:
            continue

        brand_list = [{"name": b, "models": sorted(m, key=lambda x: x[0].lower())}
                      for b, m in sorted(brands.items(), key=lambda x: x[0].lower())]

        with open(os.path.join(out, category + ".json"), "w") as f:
            json.dump(brand_list, f, separators=(",", ":"))

        index.append({"id": category, "title": tidy(category),
                      "layout": LAYOUTS.get(category, "generic"),
                      "brands": len(brand_list), "models": n})

    with open(os.path.join(out, "index.json"), "w") as f:
        json.dump(index, f, separators=(",", ":"), indent=None)

    print("%d categories, %d remotes" % (len(index), sum(c["models"] for c in index)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)

    main(sys.argv[1], sys.argv[2])

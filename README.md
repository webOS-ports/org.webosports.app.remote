Remote
======

Summary
-------
Universal remote for LuneOS devices with an infrared transmitter.

Description
-----------
A universal remote for LuneOS devices with an infrared transmitter (IR
blaster), such as the Samsung Galaxy Tab Pro 10.1 (SM-T520).

Pick the kind of device, its brand and its model, and the app lays out a
remote from the keys that model has: power, input and mute; volume and
channel (or temperature, fan speed, brightness) either side of the arrow pad;
menu keys, transport, colour keys, a number pad, and every other key the
remote has in a grid at the bottom. If the exact model is not listed, "Try" on
each row sends a harmless key so the right code set is quick to find.

How it fits together
--------------------

- **Codes**: [Flipper-IRDB](https://github.com/Lucaslhm/Flipper-IRDB) (CC0-1.0),
  turned into compact JSON at build time by `tools/build-irdb.py`. Its
  `_Converted_` folder is left out: it is bulk-converted from databases under
  other licences.
- **Encoding**: `qml/js/IrEncoder.js` turns a decoded code (NEC, NECext, NEC42,
  Samsung32, RC5, RC5X, RC6, SIRC, SIRC15, SIRC20, Kaseikyo, RCA, Pioneer)
  into timings. It is ported from the Flipper Zero firmware and checked
  against it.
- **Sending**: `org.webosports.service.ir` (`ir.operation` group) owns the
  transmitter.
- **Layout**: `qml/js/ButtonMap.js` sorts each file's keys into the slots of a
  physical remote, from the spellings that occur in the database.
- **Saved remotes**: LocalStorage, keeping only the pointer into the database.

Building
--------

CMake with the webOS modules, as every LuneOS app. `IRDB_SOURCE_DIR` must point
at a Flipper-IRDB checkout:

    cmake -DIRDB_SOURCE_DIR=/path/to/Flipper-IRDB ..

For a quick try on a device over adb:

    tools/deploy.sh /path/to/Flipper-IRDB [adb serial]

Tests
-----

On the build host, with luneos-components' desktop build (`CONFIG+=desktop`,
see its README):

    tests/run-qml-tests.sh /path/to/luneos-components

- `tests/qml/tst_ui.qml`, once: touch and hold a remote, Rename and Remove,
  answered with the dialogs' buttons.
- `tests/qml/tst_screens.qml`, once per device screen in `PROFILES` (by
  default `mindphone q25 tp radon`: 480x800, 720x720, 1024x768 and the
  FuriPhone FLX1s' 720x1600 with its notch and rounded corners), each run
  with that screen's size and grid unit: the remotes, empty and not, the hold
  menu, Rename and Remove, the no-transmitter and send-failed notices, adding
  a remote (kinds, brands, models with Try, the remote on trial with Save),
  and a saved remote of each layout (TV, media, audio, climate, fan, light,
  camera, generic), every page of its keys. Each screen is checked for being
  shown, inside the window, not wider than it, and keys not on top of each
  other, and saved as `build/test-output/ui/<profile>-<screen>.png`, with the
  panel's notch and corners painted black on radon. Three faults show as
  expected failures (XFAIL) until they are fixed: a remote whose keys are
  all numbered (the LED strip) opens on an empty first page; on a narrow
  screen a light's three rockers under the arrow pad run off both sides;
  on the Q25 the arrows overlap OK by a pixel or two.

The screens read their codes from `tests/data/irdb`: a few categories made by
`tools/build-irdb.py` from Flipper-IRDB (CC0-1.0) - for each, its first three
brands' first two remotes and the remote with the most keys. `PROFILES=q25`
runs one screen, `TESTS=` skips `tst_ui.qml`.

Licence
-------

GPL-3.0-only. The code database is CC0-1.0.

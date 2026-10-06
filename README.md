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

Licence
-------

GPL-3.0-only. The code database is CC0-1.0.

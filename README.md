# Bluetooth Device Finder

A minimal script that scans for nearby Bluetooth LE devices and shows a
live signal-strength percentage for each one. Walk toward a device and
watch its number climb; walk away and watch it fall — handy for finding a
lost phone, tag, or headset when a native tracker (e.g. Find My) isn't
available.

## Requirements

- Python 3.9+
- A computer with a Bluetooth radio (macOS, Linux, or Windows)

## Setup

```bash
pip install -r requirements.txt
```

## Usage

```bash
python bluetooth_finder.py
```

This prints a live, continuously-updating list of every nearby BLE device,
sorted strongest signal first:

```
iPhone                    82%  [########################------]  -46 dBm  AA:BB:CC:DD:EE:FF
Unnamed device             31%  [#########---------------------]  -82 dBm  11:22:33:44:55:66
```

Once you spot your device in the list, narrow to just it by name:

```bash
python bluetooth_finder.py --name "iPhone"
```

Press `Ctrl+C` to stop scanning.

## Notes

- The percentage is derived from RSSI (radio signal strength), not a true
  distance measurement — it's a relative "warmer/colder" indicator, not
  precise ranging.
- The first run may prompt for Bluetooth permission from your OS
  (especially macOS) — allow it for the script to see any devices.
- This runs on a desktop/laptop with a Bluetooth radio. It does not run on
  iOS — iPhones don't allow arbitrary scripts to execute outside the
  App Store/Xcode app-signing model.

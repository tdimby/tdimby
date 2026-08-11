#!/usr/bin/env python3
"""
Bluetooth phone finder.

Scans for nearby Bluetooth LE devices and shows a live signal-strength
percentage for each one. Walk toward a device and watch its number climb;
walk away and watch it fall. Useful for finding a lost phone/tag when you
can't use Find My / a native tracker.

Usage:
    pip install bleak
    python bluetooth_finder.py

Optional: filter to one device once you spot it in the list:
    python bluetooth_finder.py --name "iPhone"
"""

import argparse
import asyncio
import sys

from bleak import BleakScanner

# -40 dBm ~= right next to it, -100 dBm ~= about as far as BLE reaches indoors.
RSSI_NEAR = -40
RSSI_FAR = -100


def rssi_to_percent(rssi: int) -> int:
    clamped = max(RSSI_FAR, min(RSSI_NEAR, rssi))
    return round((clamped - RSSI_FAR) / (RSSI_NEAR - RSSI_FAR) * 100)


def bar(percent: int, width: int = 30) -> str:
    filled = round(width * percent / 100)
    return "#" * filled + "-" * (width - filled)


async def main(name_filter: str | None) -> None:
    print("Scanning for nearby Bluetooth devices... (Ctrl+C to stop)\n")

    seen: dict[str, tuple[str, int]] = {}

    def on_detect(device, advertisement_data):
        name = device.name or advertisement_data.local_name or "Unnamed device"
        if name_filter and name_filter.lower() not in name.lower():
            return
        rssi = advertisement_data.rssi
        if rssi is None:
            return
        seen[device.address] = (name, rssi)
        render()

    def render():
        # Redraw in place so it reads like a live meter, not a scrolling log.
        sys.stdout.write("\033[H\033[J")
        print("Scanning for nearby Bluetooth devices... (Ctrl+C to stop)\n")
        for address, (name, rssi) in sorted(seen.items(), key=lambda kv: -kv[1][1]):
            percent = rssi_to_percent(rssi)
            print(f"{name:<24} {percent:>3}%  [{bar(percent)}]  {rssi} dBm  {address}")

    scanner = BleakScanner(on_detect)
    await scanner.start()
    try:
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        await scanner.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--name",
        default=None,
        help="Only show devices whose name contains this text (e.g. --name iPhone)",
    )
    args = parser.parse_args()

    try:
        asyncio.run(main(args.name))
    except KeyboardInterrupt:
        pass

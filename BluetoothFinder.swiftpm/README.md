# Bluetooth Finder (Swift Playgrounds)

A real native Bluetooth scanner app for iPhone/iPad, built to open directly
in Swift Playgrounds. It uses CoreBluetooth (Apple's own framework), so it
works on-device with no browser restrictions, no extensions, and no backend.

## How to run it

1. Copy the whole `BluetoothFinder.swiftpm` folder onto your iPhone or iPad
   (AirDrop it to yourself, or put it in iCloud Drive/Files and open it
   from there).
2. Tap the folder — it opens directly in the **Swift Playgrounds** app
   (free, from the App Store, if you don't already have it).
3. Tap the Run button (▶) in the top right.
4. The first time you tap "Start Scan," iOS will show the real Bluetooth
   permission prompt — allow it.

No Mac, no Xcode, and no Apple Developer account are required just to run
it inside Swift Playgrounds on your device. You'd only need those if you
want to install it permanently as a home-screen app instead of running it
from within Playgrounds.

## What it does

- Tap **Start Scan** to continuously sweep for nearby Bluetooth LE devices.
- Every device found shows up as a row with a live percentage bar, derived
  from its real signal strength (RSSI) — the number climbs as you walk
  toward the device and falls as you walk away.
- Tap **Stop Scan** to pause.

## Files

- `Package.swift` — Swift Playgrounds app manifest (bundle id, icon,
  accent color, and the Bluetooth permission string).
- `Sources/BluetoothFinderApp.swift` — app entry point.
- `Sources/BluetoothScanner.swift` — the CoreBluetooth scanning logic
  (an `ObservableObject` wrapping `CBCentralManager`).
- `Sources/ContentView.swift` — the SwiftUI screen: device list, signal
  bars, and the Start/Stop Scan button.

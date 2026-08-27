// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "BluetoothFinder",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "BluetoothFinder",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.bluetoothfinder",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .antenna),
            accentColor: .presetColor(.teal),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .bluetoothAlways(purposeString: "Bluetooth Finder scans for nearby Bluetooth devices and shows their live signal strength so you can locate them.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)

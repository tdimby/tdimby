// swift-tools-version: 5.9

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MusicRate",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "MusicRate",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.musicrate",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .note),
            accentColor: .presetColor(.green),
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
                .outgoingNetworkConnections()
            ],
            additionalInfoPlistContentFilePath: "AdditionalInfo.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)

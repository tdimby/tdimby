import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = BluetoothScanner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusBar

                if scanner.devices.isEmpty {
                    Spacer()
                    Text(scanner.isScanning ? "Listening for nearby devices…" : "No devices found yet")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(scanner.devices) { device in
                        DeviceRow(device: device)
                            .listRowBackground(Color(white: 0.08))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                Button(action: toggleScan) {
                    Label(scanner.isScanning ? "Stop Scan" : "Start Scan", systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Bluetooth Finder")
            .background(Color.black.ignoresSafeArea())
        }
    }

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(scanner.isScanning ? Color.teal : Color.gray)
                .frame(width: 8, height: 8)
            Text(scanner.statusMessage)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func toggleScan() {
        scanner.isScanning ? scanner.stopScan() : scanner.startScan()
    }
}

private struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(device.name)
                    .font(.system(.body, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(device.percent)%")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.teal)
            }
            ProgressView(value: Double(device.percent), total: 100)
                .tint(.teal)
            Text("\(device.rssi) dBm")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

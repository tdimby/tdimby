import CoreBluetooth
import Foundation

struct DiscoveredDevice: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var lastSeen: Date

    var percent: Int {
        // -40 dBm ~= right next to it, -100 dBm ~= about as far as BLE reaches indoors.
        let clamped = max(-100, min(-40, rssi))
        return Int((Double(clamped) - -100) / (-40 - -100) * 100)
    }
}

@MainActor
final class BluetoothScanner: NSObject, ObservableObject {
    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var statusMessage = "Tap Start Scan to begin"

    private var centralManager: CBCentralManager!
    private var deviceIndex: [UUID: Int] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "Bluetooth is off or not authorized yet"
            return
        }
        devices = []
        deviceIndex = [:]
        isScanning = true
        statusMessage = "Scanning..."
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Scan stopped"
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                statusMessage = isScanning ? "Scanning..." : "Ready — tap Start Scan"
            case .poweredOff:
                statusMessage = "Turn on Bluetooth to scan"
            case .unauthorized:
                statusMessage = "Bluetooth permission denied — enable it in Settings"
            case .unsupported:
                statusMessage = "This device doesn't support Bluetooth LE"
            default:
                statusMessage = "Waiting for Bluetooth..."
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unnamed device"
        let id = peripheral.identifier
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            if let index = deviceIndex[id] {
                devices[index].rssi = rssiValue
                devices[index].lastSeen = Date()
                if devices[index].name == "Unnamed device", name != "Unnamed device" {
                    devices[index].name = name
                }
            } else {
                let device = DiscoveredDevice(id: id, name: name, rssi: rssiValue, lastSeen: Date())
                deviceIndex[id] = devices.count
                devices.append(device)
            }
            devices.sort { $0.rssi > $1.rssi }
            // Resync the index after sorting so future updates land on the right row.
            for (i, device) in devices.enumerated() {
                deviceIndex[device.id] = i
            }
        }
    }
}

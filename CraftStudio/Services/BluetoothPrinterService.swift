import Foundation
import CoreBluetooth
import AppKit

struct BLEPeripheral: Identifiable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
}

class BluetoothPrinterService: NSObject, ObservableObject {
    @Published var isBluetoothEnabled = false
    @Published var discoveredPeripherals: [BLEPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isConnecting = false
    @Published var connectionError: String?
    
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scan() {
        discoveredPeripherals.removeAll()
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    func connect(to peripheral: CBPeripheral) {
        isConnecting = true
        connectionError = nil
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let connected = connectedPeripheral {
            centralManager.cancelPeripheralConnection(connected)
        }
    }
    
    func printData(image: NSImage, scale: Float) {
        guard let peripheral = connectedPeripheral, let characteristic = writeCharacteristic else {
            DispatchQueue.main.async {
                self.connectionError = "Non connecté ou caractéristique d'écriture non trouvée."
            }
            return
        }
        
        let targetSize = NSSize(
            width: image.size.width * CGFloat(scale / 100.0),
            height: image.size.height * CGFloat(scale / 100.0)
        )
        guard let resized = image.resized(to: targetSize) else { return }
        
        let rasterData = createRasterData(from: resized)
        
        let maxWriteSize = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let chunkSize = maxWriteSize > 0 ? maxWriteSize : 128
        
        DispatchQueue.global(qos: .userInitiated).async { // Don't block main thread during slow transmission
            var offset = 0
            while offset < rasterData.count {
                let end = min(offset + chunkSize, rasterData.count)
                let chunk = rasterData[offset..<end]
                peripheral.writeValue(Data(chunk), for: characteristic, type: .withoutResponse)
                offset = end
                
                // Petit délai pour éviter la congestion du buffer Bluetooth / Imprimante (Phomemo sont lentes)
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
    }
    
    private func createRasterData(from image: NSImage) -> Data {
        var data = Data()
        // Initialization standard ESC/POS
        data.append(contentsOf: [0x1B, 0x40])
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 1, // Grayscale
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .calibratedWhite,
            bytesPerRow: width,
            bitsPerPixel: 8
        )
        
        guard let bitmapRep = rep else { return data }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        
        // Fond blanc pour éliminer la transparence
        NSColor.white.set()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        
        NSGraphicsContext.restoreGraphicsState()
        
        let widthInBytes = (width + 7) / 8
        
        // GS v 0 (print raster bit image, normal size)
        data.append(contentsOf: [0x1D, 0x76, 0x30, 0x00])
        data.append(contentsOf: [UInt8(widthInBytes % 256), UInt8(widthInBytes / 256)])
        data.append(contentsOf: [UInt8(height % 256), UInt8(height / 256)])
        
        guard let pixelData = bitmapRep.bitmapData else { return data }
        
        for y in 0..<height {
            for xByte in 0..<widthInBytes {
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let x = xByte * 8 + bit
                    if x < width {
                        // Les coordonnées d'image NSBitmap sont stockées avec (0,0) en haut à gauche
                        let pixelIndex = y * bitmapRep.bytesPerRow + x
                        let intensity = pixelData[pixelIndex]
                        // Seuil pour Noir (< 128)
                        if intensity < 128 { 
                            byte |= (1 << (7 - bit))
                        }
                    }
                }
                data.append(byte)
            }
        }
        
        // Avance de papier
        data.append(contentsOf: [0x1B, 0x64, 0x05]) // Feed 5 lines
        
        return data
    }
}

extension BluetoothPrinterService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.isBluetoothEnabled = (central.state == .poweredOn)
            if self.isBluetoothEnabled {
                self.scan()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let name = peripheral.name, !name.isEmpty, name.lowercased().contains("tp31") || name.lowercased().contains("phomemo") || name.lowercased().contains("t02") || name.lowercased().contains("m02") {
            DispatchQueue.main.async {
                if !self.discoveredPeripherals.contains(where: { $0.id == peripheral.identifier }) {
                    let newDevice = BLEPeripheral(id: peripheral.identifier, name: name, peripheral: peripheral)
                    self.discoveredPeripherals.append(newDevice)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isConnecting = false
            self.connectedPeripheral = peripheral
        }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnecting = false
            self.connectionError = error?.localizedDescription ?? "Échec de la connexion"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.scan()
        }
    }
}

extension BluetoothPrinterService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.writeWithoutResponse) || characteristic.properties.contains(.write) {
                self.writeCharacteristic = characteristic
            }
        }
    }
}

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}

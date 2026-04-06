import SwiftUI
import UniformTypeIdentifiers

struct PrintView: View {
    @StateObject private var bluetoothService = BluetoothPrinterService()
    
    @State private var sourceImage: NSImage?
    @State private var sourceFileName: String = ""
    @State private var printScale: Float = 100.0
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Content
            ScrollView {
                VStack(spacing: CSSpacing.lg) {
                    
                    // Composant de Connexion Bluetooth
                    bluetoothSection
                    
                    if let error = errorMessage ?? bluetoothService.connectionError {
                        errorBanner(error)
                    }
                    
                    // Zone de Dépôt (désactivée si non connecté)
                    if sourceImage == nil {
                        VStack(spacing: CSSpacing.sm) {
                            dropZone
                                .opacity(bluetoothService.connectedPeripheral == nil ? 0.6 : 1.0)
                                .disabled(bluetoothService.connectedPeripheral == nil)
                            
                            if bluetoothService.connectedPeripheral == nil {
                                Text("Connectez une imprimante Bluetooth pour importer une image.")
                                    .font(.csCaption)
                                    .foregroundStyle(Color.csTextSecondary)
                            }
                        }
                    } else {
                        imagePreview
                        controls
                        exportButtons
                    }
                }
                .padding(CSSpacing.xl)
            }
        }
        .onDisappear {
            bluetoothService.stopScan()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Imprimer")
                    .font(.csTitle)
                    .foregroundStyle(Color.csTextPrimary)
                Text("Préparez et envoyez vos designs à l'impression thermique Bluetooth")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
            }
            
            Spacer()
            
            if sourceImage != nil {
                Button(action: reset) {
                    HStack(spacing: CSSpacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Nouvelle image")
                    }
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
                    .padding(.horizontal, CSSpacing.md)
                    .padding(.vertical, CSSpacing.sm)
                    .background(Color.csSurfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CSRadius.small, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CSSpacing.xl)
        .padding(.top, CSSpacing.lg)
        .padding(.bottom, CSSpacing.md)
    }
    
    // MARK: - Bluetooth Section
    
    private var bluetoothSection: some View {
        VStack(alignment: .leading, spacing: CSSpacing.md) {
            HStack {
                Text("Imprimante Bluetooth")
                    .font(.csHeadline)
                    .foregroundStyle(Color.csTextPrimary)
                
                Spacer()
                
                if bluetoothService.isBluetoothEnabled {
                    if bluetoothService.isConnecting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(.trailing, CSSpacing.xs)
                        Text("Connexion...")
                            .font(.csCaption)
                            .foregroundStyle(Color.csTextSecondary)
                    } else if let connected = bluetoothService.connectedPeripheral {
                        Text("Connecté : \(connected.name ?? "Phomemo")")
                            .font(.csCaption)
                            .foregroundStyle(Color.csSuccess)
                        
                        Button("Déconnecter") {
                            bluetoothService.disconnect()
                        }
                        .font(.csCaption)
                        .foregroundStyle(Color.csDanger)
                        .buttonStyle(.plain)
                        .padding(.leading, CSSpacing.md)
                    } else {
                        Button(action: {
                            bluetoothService.scan()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Rechercher")
                            }
                        }
                        .font(.csCaption)
                        .foregroundStyle(Color.csAccent)
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Veuillez activer le Bluetooth de votre Mac")
                        .font(.csCaption)
                        .foregroundStyle(Color.csDanger)
                }
            }
            
            if bluetoothService.connectedPeripheral == nil && bluetoothService.isBluetoothEnabled && !bluetoothService.isConnecting {
                if bluetoothService.discoveredPeripherals.isEmpty {
                    HStack {
                        Spacer()
                        Text("Recherche d'imprimantes (Phomemo/TP/M02) en cours...")
                            .font(.csBody)
                            .foregroundStyle(Color.csTextSecondary)
                            .padding(.vertical, CSSpacing.md)
                        Spacer()
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CSSpacing.md) {
                            ForEach(bluetoothService.discoveredPeripherals) { device in
                                Button(action: {
                                    bluetoothService.connect(to: device.peripheral)
                                }) {
                                    VStack(spacing: CSSpacing.sm) {
                                        Image(systemName: "printer.dotmatrix.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color.csAccent)
                                        Text(device.name)
                                            .font(.csCaption)
                                            .foregroundStyle(Color.csTextPrimary)
                                    }
                                    .padding(.horizontal, CSSpacing.lg)
                                    .padding(.vertical, CSSpacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                                            .fill(Color.csSurfaceSecondary.opacity(0.5))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                                            .strokeBorder(Color.csBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, CSSpacing.xs)
                    }
                }
            }
        }
        .csCard()
    }
    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        DropZoneView(
            title: "Glissez votre modèle ici",
            subtitle: "Formats acceptés : JPG, PNG, SVG",
            icon: "doc.viewfinder",
            acceptedTypes: [.jpeg, .png, .svg, .image],
            onDrop: handleImageDrop,
            onImageLoaded: { image in
                withAnimation {
                    sourceImage = image
                    sourceFileName = "Importé depuis Photos"
                    errorMessage = nil
                }
            }
        )
        .frame(minHeight: 300)
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        VStack(spacing: CSSpacing.sm) {
            Text("Aperçu du modèle")
                .font(.csCaption)
                .foregroundStyle(Color.csTextSecondary)
            
            if let source = sourceImage {
                ZStack {
                    RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                        .fill(Color(white: 0.95)) // Light background like paper
                    
                    Image(nsImage: source)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(CGFloat(printScale / 100.0))
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
                }
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
                .csSubtleShadow()
            }
        }
        .csCard()
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        VStack(spacing: CSSpacing.md) {
            
            // Slider Redimensionnement
            VStack(spacing: CSSpacing.xs) {
                HStack {
                    Text("Échelle de la trame thermique (\(Int(printScale))%)")
                        .font(.csBody)
                        .foregroundStyle(Color.csTextPrimary)
                    Spacer()
                    Button("Réinitialiser") {
                        printScale = 100.0
                    }
                    .font(.csCaption)
                    .foregroundStyle(Color.csAccent)
                    .buttonStyle(.plain)
                }
                
                Slider(
                    value: $printScale, 
                    in: 10...200, 
                    step: 5
                )
                .tint(Color.csAccent)
                .background(
                    Capsule()
                        .fill(Color.csBorder.opacity(0.8))
                        .frame(height: 4)
                )
            }
        }
        .csCard()
    }
    
    // MARK: - Export Buttons
    
    private var exportButtons: some View {
        HStack(spacing: CSSpacing.md) {
            ActionButton(
                title: "Envoyer à l'imprimante (BLE)",
                icon: "dot.radiowaves.left.and.right",
                style: .primary,
                isDisabled: sourceImage == nil || bluetoothService.connectedPeripheral == nil
            ) {
                printDesign()
            }
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: CSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.csDanger)
            Text(message)
                .font(.csBody)
                .foregroundStyle(Color.csTextPrimary)
            Spacer()
            Button(action: { withAnimation { 
                errorMessage = nil 
                bluetoothService.connectionError = nil
            } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.csTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(CSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                .fill(Color.csDanger.opacity(0.08))
        )
        .padding(.horizontal, CSSpacing.xl)
    }
    
    // MARK: - Actions
    
    private func handleImageDrop(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "Impossible de charger cette image."
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sourceImage = image
            sourceFileName = url.lastPathComponent
            errorMessage = nil
            printScale = 100.0
        }
    }
    
    private func printDesign() {
        guard let originalImage = sourceImage else { return }
        // Appel au service Bluetooth au lieu du NSPrintOperation
        bluetoothService.printData(image: originalImage, scale: printScale)
        
        // Confirmation visuelle temporaire (car c'est asynchrone)
        errorMessage = nil
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sourceImage = nil
            sourceFileName = ""
            errorMessage = nil
            printScale = 100.0
        }
    }
}

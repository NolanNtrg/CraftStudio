import SwiftUI
import UniformTypeIdentifiers

struct EraserView: View {
    @State private var sourceImage: NSImage?
    @State private var sourceFileName: String = ""
    @State private var resultImage: NSImage?
    @State private var brushSize: CGFloat = 30
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var successPath: String?
    @State private var canvasKey = UUID() // Force canvas refresh
    @State private var undoTrigger = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            if sourceImage == nil {
                // Drop Zone
                ScrollView {
                    dropZone
                        .padding(CSSpacing.xl)
                }
            } else {
                // Editing Mode
                VStack(spacing: 0) {
                    // Toolbar
                    toolbar
                    
                    // Canvas
                    canvas
                        .padding(.horizontal, CSSpacing.md)
                        .padding(.bottom, CSSpacing.md)
                }
            }
            
            // Banners
            VStack(spacing: CSSpacing.sm) {
                if let success = successMessage {
                    SuccessBanner(
                        message: success,
                        filePath: successPath,
                        onDismiss: {
                            withAnimation {
                                successMessage = nil
                                successPath = nil
                            }
                        }
                    )
                    .padding(.horizontal, CSSpacing.xl)
                    .padding(.bottom, CSSpacing.md)
                }
                
                if let error = errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, CSSpacing.xl)
                        .padding(.bottom, CSSpacing.md)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gommer")
                    .font(.csTitle)
                    .foregroundStyle(Color.csTextPrimary)
                Text("Effacez les parties indésirables de vos images")
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
    
    // MARK: - Drop Zone
    
    private var dropZone: some View {
        DropZoneView(
            title: "Glissez votre image ici",
            subtitle: "Formats acceptés : JPG, JPEG, PNG",
            icon: "eraser.fill",
            acceptedTypes: [.jpeg, .png, .image],
            onDrop: handleImageDrop
        )
        .frame(minHeight: 300)
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: CSSpacing.lg) {
            // Brush size control
            HStack(spacing: CSSpacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.csTextSecondary)
                
                Slider(value: $brushSize, in: 5...80, step: 1)
                    .tint(Color.csAccent)
                    .background(
                        Capsule()
                            .fill(Color.csBorder.opacity(0.8))
                            .frame(height: 4)
                    )
                    .frame(width: 160)
                
                Image(systemName: "circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.csTextSecondary)
                
                Text("\(Int(brushSize)) px")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .leading)
            }
            
            Divider()
                .frame(height: 20)
            
            // Undo & Reset
            Button(action: {
                undoTrigger += 1
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Annuler")
                }
                .font(.csCaption)
                .foregroundStyle(Color.csTextSecondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("z", modifiers: .command)
            
            Button(action: resetCanvas) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Réinitialiser")
                }
                .font(.csCaption)
                .foregroundStyle(Color.csDanger)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Save button
            ActionButton(
                title: "Enregistrer PNG",
                icon: "square.and.arrow.down",
                style: .primary,
                isDisabled: resultImage == nil
            ) {
                saveResult()
            }
        }
        .padding(.horizontal, CSSpacing.xl)
        .padding(.vertical, CSSpacing.sm)
        .background(Color.csSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    // MARK: - Canvas
    
    private var canvas: some View {
        ZStack {
            if let image = sourceImage {
                EraserCanvasView(
                    image: image,
                    brushSize: $brushSize,
                    resultImage: $resultImage,
                    undoTrigger: $undoTrigger,
                    onUpdate: {}
                )
                .id(canvasKey)
                .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
                .csSubtleShadow()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.csSurfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CSRadius.large, style: .continuous))
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
        }
        .padding(CSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                .fill(Color.csDanger.opacity(0.08))
        )
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
            resultImage = nil
            errorMessage = nil
            successMessage = nil
            canvasKey = UUID()
        }
    }
    
    private func saveResult() {
        guard let image = resultImage else { return }
        
        do {
            let url = try ImageExportService.shared.saveErasedPNGToDownloads(
                image: image,
                originalName: sourceFileName
            )
            withAnimation {
                successMessage = "Image nettoyée enregistrée"
                successPath = url.path
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func resetCanvas() {
        canvasKey = UUID()
        resultImage = nil
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sourceImage = nil
            sourceFileName = ""
            resultImage = nil
            errorMessage = nil
            successMessage = nil
            successPath = nil
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct VectorizeView: View {
    @State private var sourceImage: NSImage?
    @State private var sourceFileName: String = ""
    @State private var vectorResult: VectorizationService.VectorizationResult?
    
    // Nouveaux états adaptés à notre service
    @State private var threshold: Float = 50.0
    @State private var smoothness: Float = 2.0
    
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var successPath: String?
    
    private let vectorizationService = VectorizationService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Content
            ScrollView {
                VStack(spacing: CSSpacing.lg) {
                    if sourceImage == nil {
                        dropZone
                    } else {
                        imagePreview
                        controls
                        exportButtons
                    }
                    
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
                    }
                    
                    if let error = errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(CSSpacing.xl)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Vectoriser")
                    .font(.csTitle)
                    .foregroundStyle(Color.csTextPrimary)
                Text("Transformez vos images en tracés vectoriels")
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
            icon: "photo.on.rectangle.angled",
            acceptedTypes: [.jpeg, .png, .image],
            onDrop: handleImageDrop
        )
        .frame(minHeight: 300)
    }
    
    // MARK: - Image Preview
    
    private var imagePreview: some View {
        HStack(spacing: CSSpacing.lg) {
            // Original
            VStack(spacing: CSSpacing.sm) {
                Text("Original")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
                
                if let source = sourceImage {
                    Image(nsImage: source)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
                        .csSubtleShadow()
                }
            }
            .frame(maxWidth: .infinity)
            
            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.csTextTertiary)
            
            // Vectorized
            VStack(spacing: CSSpacing.sm) {
                Text("Vectorisé")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
                
                if let result = vectorResult {
                    Image(nsImage: result.renderedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
                        .csSubtleShadow()
                } else {
                    RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                        .fill(Color.csSurfaceSecondary)
                        .frame(height: 200)
                        .overlay(
                            Text("Ajustez les paramètres pour lancer la vectorisation")
                                .font(.csSmall)
                                .foregroundStyle(Color.csTextTertiary)
                        )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .csCard()
    }
    
    // MARK: - Controls
    
    private var controls: some View {
        VStack(spacing: CSSpacing.md) {
            
            // Slider Seuil
            VStack(spacing: CSSpacing.xs) {
                HStack {
                    Text("Seuil de détection")
                        .font(.csBody)
                        .foregroundStyle(Color.csTextPrimary)
                    Spacer()
                    Text("\(Int(threshold))%")
                        .font(.csCaption)
                        .foregroundStyle(Color.csAccent)
                        .monospacedDigit()
                }
                
                Slider(
                    value: $threshold, 
                    in: 0...100, 
                    step: 1,
                    onEditingChanged: { isEditing in
                        if !isEditing { vectorize() }
                    }
                )
                .tint(Color.csAccent)
                .background(
                    Capsule()
                        .fill(Color.csBorder.opacity(0.8))
                        .frame(height: 4)
                )
            }
            
            // Slider Lissage
            VStack(spacing: CSSpacing.xs) {
                HStack {
                    Text("Niveau de lissage")
                        .font(.csBody)
                        .foregroundStyle(Color.csTextPrimary)
                    Spacer()
                    Text("\(Int(smoothness))")
                        .font(.csCaption)
                        .foregroundStyle(Color.csAccent)
                        .monospacedDigit()
                }
                
                Slider(
                    value: $smoothness, 
                    in: 0...10, 
                    step: 1,
                    onEditingChanged: { isEditing in
                        if !isEditing { vectorize() }
                    }
                )
                .tint(Color.csAccent)
                .background(
                    Capsule()
                        .fill(Color.csBorder.opacity(0.8))
                        .frame(height: 4)
                )
            }
            .padding(.bottom, CSSpacing.sm)
        }
        .csCard()
    }
    
    // MARK: - Export Buttons
    
    private var exportButtons: some View {
        HStack(spacing: CSSpacing.md) {
            ActionButton(
                title: "Enregistrer en SVG",
                icon: "square.and.arrow.down",
                style: .primary,
                isDisabled: vectorResult == nil
            ) {
                saveSVG()
            }
            
            ActionButton(
                title: "Enregistrer en PNG",
                icon: "photo.badge.arrow.down",
                style: .secondary,
                isDisabled: vectorResult == nil
            ) {
                savePNGToPhotos()
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
            Button(action: { withAnimation { errorMessage = nil } }) {
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
            vectorResult = nil
            errorMessage = nil
            successMessage = nil
        }
        
        // Lance automatiquement la vectorisation peu après l'import
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            vectorize()
        }
    }
    
    private func vectorize() {
        guard let image = sourceImage else { return }
        
        errorMessage = nil
        
        vectorizationService.threshold = threshold
        vectorizationService.smoothness = smoothness
        
        Task {
            do {
                let result = try await vectorizationService.vectorize(image: image)
                await MainActor.run {
                    withAnimation {
                        vectorResult = result
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func saveSVG() {
        guard let result = vectorResult else { return }
        
        do {
            let url = try ImageExportService.shared.saveSVGToDownloads(
                svgString: result.svgString,
                originalName: sourceFileName
            )
            withAnimation {
                successMessage = "SVG enregistré avec succès"
                successPath = url.path
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func savePNGToPhotos() {
        guard let result = vectorResult else { return }
        
        Task {
            do {
                try await ImageExportService.shared.saveToPhotos(image: result.renderedImage)
                await MainActor.run {
                    withAnimation {
                        successMessage = "Image ajoutée à la photothèque"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sourceImage = nil
            sourceFileName = ""
            vectorResult = nil
            errorMessage = nil
            successMessage = nil
            successPath = nil
        }
    }
}
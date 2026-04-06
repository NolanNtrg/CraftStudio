import SwiftUI
import UniformTypeIdentifiers
import AppKit
import PhotosUI

struct DropZoneView: View {
    let title: String
    let subtitle: String
    let icon: String
    let acceptedTypes: [UTType]
    let onDrop: (URL) -> Void
    /// Optional callback for direct NSImage delivery (used by PhotosPicker)
    var onImageLoaded: ((NSImage) -> Void)? = nil
    
    @State private var isTargeted = false
    @State private var dashPhase: CGFloat = 0
    @State private var isBrowseHovered = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    /// Detect if this drop zone handles images (show PhotosPicker) or other types (show Finder)
    private var isImageType: Bool {
        acceptedTypes.contains(where: { $0.conforms(to: .image) })
    }
    
    var body: some View {
        VStack(spacing: CSSpacing.md) {
            ZStack {
                // Animated dashed border
                RoundedRectangle(cornerRadius: CSRadius.extraLarge, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6],
                                          dashPhase: isTargeted ? dashPhase : 0)
                    )
                    .foregroundStyle(isTargeted ? Color.csAccent : Color.csBorder)
                    .background(
                        RoundedRectangle(cornerRadius: CSRadius.extraLarge, style: .continuous)
                            .fill(isTargeted ? Color.csAccentLight : Color.csSurfaceSecondary.opacity(0.5))
                    )
                
                VStack(spacing: CSSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(isTargeted ? Color.csAccent.opacity(0.15) : Color.csSurfaceSecondary)
                            .frame(width: 64, height: 64)
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(isTargeted ? Color.csAccent : Color.csTextSecondary)
                    }
                    .scaleEffect(isTargeted ? 1.1 : 1.0)
                    
                    VStack(spacing: CSSpacing.xs) {
                        Text(title)
                            .font(.csHeadline)
                            .foregroundStyle(Color.csTextPrimary)
                        Text(subtitle)
                            .font(.csCaption)
                            .foregroundStyle(Color.csTextSecondary)
                    }
                    
                    // Browse button: PhotosPicker for images, Finder for other types
                    if isImageType {
                        HStack(spacing: CSSpacing.md) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                browseLabel(text: "Importer depuis Photos", icon: "photo.on.rectangle")
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                handlePhotoSelection(newItem)
                            }
                            
                            Text("ou")
                                .font(.csCaption)
                                .foregroundStyle(Color.csTextSecondary)
                            
                            Button(action: openFilePicker) {
                                browseLabel(text: "Rechercher dans Finder", icon: "folder")
                            }
                            .buttonStyle(.plain)
                            .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isBrowseHovered = h } }
                        }
                    } else {
                        Button(action: openFilePicker) {
                            browseLabel(text: "Rechercher un fichier", icon: "folder.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isBrowseHovered = h } }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 220)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { dashPhase = 28 }
            } else { dashPhase = 0 }
        }
    }
    
    // MARK: - Shared Button Label
    
    private func browseLabel(text: String, icon: String) -> some View {
        HStack(spacing: CSSpacing.sm) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
            Text(text).font(.csButton)
        }
        .foregroundStyle(Color.csAccent)
        .padding(.horizontal, CSSpacing.lg)
        .padding(.vertical, CSSpacing.sm + 2)
        .background(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous).fill(Color.csAccentLight))
        .overlay(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous).strokeBorder(Color.csAccent.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - PhotosPicker Handler
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        Task {
            guard let item = item,
                  let data = try? await item.loadTransferable(type: Data.self) else { return }
            
            // If we have a direct image callback, use it
            if let onImageLoaded = onImageLoaded, let image = NSImage(data: data) {
                DispatchQueue.main.async { onImageLoaded(image) }
                return
            }
            
            // Otherwise save to temp and call onDrop with URL
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".png")
            try? data.write(to: tempURL)
            DispatchQueue.main.async { onDrop(tempURL) }
        }
    }
    
    // MARK: - Finder Picker (for non-image types)
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = acceptedTypes
        panel.message = "Sélectionnez un fichier"
        panel.prompt = "Ouvrir"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async { onDrop(url) }
            }
        }
    }
    
    // MARK: - Drag & Drop
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil, let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                guard let fileType = UTType(filenameExtension: url.pathExtension),
                      acceptedTypes.contains(where: { fileType.conforms(to: $0) }) else { return }
                DispatchQueue.main.async { onDrop(url) }
            }
            return true
        }
        return false
    }
}

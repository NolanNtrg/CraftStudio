import Foundation
import AppKit
import Photos

/// Service handling image export to Downloads folder and Photos library
class ImageExportService {
    
    static let shared = ImageExportService()
    
    // MARK: - Save to Downloads
    
    func saveToDownloads(data: Data, filename: String) throws -> URL {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent(filename)
        
        // Handle duplicate filenames
        let finalURL = uniqueFileURL(for: fileURL)
        
        try data.write(to: finalURL)
        return finalURL
    }
    
    func saveSVGToDownloads(svgString: String, originalName: String) throws -> URL {
        let baseName = (originalName as NSString).deletingPathExtension
        let filename = "\(baseName)_vector.svg"
        guard let data = svgString.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }
        return try saveToDownloads(data: data, filename: filename)
    }
    
    func savePNGToDownloads(image: NSImage, originalName: String) throws -> URL {
        let baseName = (originalName as NSString).deletingPathExtension
        let filename = "\(baseName)_vector.png"
        guard let data = image.pngData() else {
            throw ExportError.encodingFailed
        }
        return try saveToDownloads(data: data, filename: filename)
    }
    
    func saveErasedPNGToDownloads(image: NSImage, originalName: String) throws -> URL {
        let baseName = (originalName as NSString).deletingPathExtension
        let filename = "\(baseName)_erased.png"
        guard let data = image.pngData() else {
            throw ExportError.encodingFailed
        }
        return try saveToDownloads(data: data, filename: filename)
    }
    
    // MARK: - Save to Photos
    
    func saveToPhotos(image: NSImage) async throws {
        // Request authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        guard status == .authorized || status == .limited else {
            throw ExportError.photosAccessDenied
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            guard let data = image.pngData() else {
                return
            }
            
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: data, options: nil)
        }
    }
    
    // MARK: - Helpers
    
    private func uniqueFileURL(for url: URL) -> URL {
        var finalURL = url
        var counter = 1
        let fm = FileManager.default
        let basePath = url.deletingPathExtension().path
        let ext = url.pathExtension
        
        while fm.fileExists(atPath: finalURL.path) {
            finalURL = URL(fileURLWithPath: "\(basePath)_\(counter).\(ext)")
            counter += 1
        }
        
        return finalURL
    }
}

// MARK: - NSImage PNG Extension

extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case encodingFailed
    case photosAccessDenied
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "L'encodage de l'image a échoué."
        case .photosAccessDenied: return "L'accès à la photothèque a été refusé."
        case .saveFailed: return "L'enregistrement a échoué."
        }
    }
}

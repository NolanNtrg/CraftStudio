import Foundation
import AppKit
import CoreGraphics
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Vectorization service using Apple's Vision framework for smooth, bezier-curve based SVG output.
class VectorizationService {
    
    struct VectorizationResult {
        let svgString: String
        let renderedImage: NSImage
        let originalSize: CGSize
    }
    
    // Échelle de 0 à 100
    var threshold: Float = 50.0 
    
    // Échelle de 0 à 10 (Sera divisé par 10 pour le flou réel)
    var smoothness: Float = 2.0 
    
    // Contexte réutilisable pour optimiser les performances de CoreImage
    private let ciContext = CIContext(options: nil)
    
    func vectorize(image: NSImage) async throws -> VectorizationResult {
        guard let originalCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VectorizationError.invalidImage
        }
        
        let width = originalCGImage.width
        let height = originalCGImage.height
        let size = CGSize(width: width, height: height)
        
        // --- 1. PRÉTRAITEMENT DE LISSAGE (Flou Gaussien) ---
        var targetCGImage = originalCGImage
        
        if smoothness > 0 {
            let ciImage = CIImage(cgImage: originalCGImage)
            // On étire les bords à l'infini pour éviter le halo noir du filtre
            let clampedImage = ciImage.clampedToExtent() 
            
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = clampedImage
            // On divise par 10 pour avoir un flou léger (max 1.0) tout en gardant un slider 0-10
            blurFilter.radius = smoothness / 10.0
            
            if let outputImage = blurFilter.outputImage?.cropped(to: ciImage.extent),
               let processedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent) {
                targetCGImage = processedCGImage
            }
        }
        
        // --- 2. DÉTECTION DES CONTOURS (Vision) ---
        let request = VNDetectContoursRequest()
        
        let clampedThreshold = max(0.0, min(threshold, 100.0))
        let visionPivotValue = clampedThreshold / 100.0
        request.contrastPivot = NSNumber(value: visionPivotValue)
        
        request.detectsDarkOnLight = true
        request.maximumImageDimension = max(width, height)
        
        // On donne l'image prétraitée (targetCGImage) à Vision
        let handler = VNImageRequestHandler(cgImage: targetCGImage, options: [:])
        try handler.perform([request])
        
        guard let observation = request.results?.first as? VNContoursObservation else {
            throw VectorizationError.tracingFailed
        }
        
        let normalizedPath = observation.normalizedPath
        
        // --- 3. TRANSFORMATION POUR LE SVG ---
        // Origine SVG en haut à gauche
        var svgTransform = CGAffineTransform(translationX: 0, y: CGFloat(height))
        svgTransform = svgTransform.scaledBy(x: CGFloat(width), y: -CGFloat(height))
        
        guard let svgPathScaled = normalizedPath.copy(using: &svgTransform) else {
            throw VectorizationError.tracingFailed
        }
        
        // --- 4. GÉNÉRATION ---
        let svgStr = generateSVG(pathString: svgPath(from: svgPathScaled), width: width, height: height)
        let preview = renderPreview(normalizedPath: normalizedPath, width: width, height: height)
        
        return VectorizationResult(svgString: svgStr, renderedImage: preview, originalSize: size)
    }
    
    // MARK: - SVG Generation
    
    private func generateSVG(pathString: String, width: Int, height: Int) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" width="\(width)" height="\(height)">
          <rect width="\(width)" height="\(height)" fill="#FFFFFF"/>
          <path d="\(pathString)" fill="#000000" fill-rule="evenodd"/>
        </svg>
        """
    }
    
    // MARK: - Conversion CGPath -> SVG Path String
    
    private func svgPath(from path: CGPath) -> String {
        var pathString = ""
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                pathString += "M \(points[0].x) \(points[0].y) "
            case .addLineToPoint:
                pathString += "L \(points[0].x) \(points[0].y) "
            case .addQuadCurveToPoint:
                pathString += "Q \(points[0].x) \(points[0].y) \(points[1].x) \(points[1].y) "
            case .addCurveToPoint:
                pathString += "C \(points[0].x) \(points[0].y) \(points[1].x) \(points[1].y) \(points[2].x) \(points[2].y) "
            case .closeSubpath:
                pathString += "Z "
            @unknown default:
                break
            }
        }
        return pathString
    }
    
    // MARK: - Preview (Optimisée avec CoreGraphics)
    
    private func renderPreview(normalizedPath: CGPath, width: Int, height: Int) -> NSImage {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        
        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        var transform = CGAffineTransform(scaleX: CGFloat(width), y: CGFloat(height))
        if let scaledPath = normalizedPath.copy(using: &transform) {
            ctx.addPath(scaledPath)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath(using: .evenOdd)
        }
        
        image.unlockFocus()
        return image
    }
}

enum VectorizationError: LocalizedError {
    case invalidImage, filterFailed, tracingFailed
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "L'image fournie est invalide."
        case .filterFailed: return "Le traitement de l'image a échoué."
        case .tracingFailed: return "La vectorisation a échoué."
        }
    }
}
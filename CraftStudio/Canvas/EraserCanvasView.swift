import SwiftUI
import AppKit

/// NSViewRepresentable wrapping a custom NSView for brush-based image "erasing"
/// Paints white over the image to simulate erasing on a white background
struct EraserCanvasView: NSViewRepresentable {
    let image: NSImage
    @Binding var brushSize: CGFloat
    @Binding var resultImage: NSImage?
    @Binding var undoTrigger: Int
    let onUpdate: () -> Void
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator {
        var lastUndoTrigger: Int = 0
    }
    
    func makeNSView(context: Context) -> EraserNSView {
        let view = EraserNSView()
        view.setImage(image)
        view.brushSize = brushSize
        context.coordinator.lastUndoTrigger = undoTrigger
        view.onImageUpdate = { updatedImage in
            DispatchQueue.main.async {
                resultImage = updatedImage
                onUpdate()
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: EraserNSView, context: Context) {
        nsView.brushSize = brushSize
        
        // Check if undo was triggered from SwiftUI
        if undoTrigger != context.coordinator.lastUndoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            nsView.undo()
        }
    }
}

// MARK: - Custom NSView for White-Brush Erasing
// Uses a NON-FLIPPED coordinate system (origin at bottom-left) to match CGContext natively.

class EraserNSView: NSView {
    
    private var editContext: CGContext?
    private var sourceSize: CGSize = .zero
    
    var brushSize: CGFloat = 30.0
    var onImageUpdate: ((NSImage) -> Void)?
    
    private var undoStack: [Data] = []
    private var isDrawing = false
    private var lastImagePoint: CGPoint?
    
    // Zoom and Pan state
    private var zoomScale: CGFloat = 1.0
    private var panOffset: CGPoint = .zero
    
    // MARK: - Setup
    
    func setImage(_ nsImage: NSImage) {
        guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        
        let width = cg.width
        let height = cg.height
        sourceSize = CGSize(width: width, height: height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        editContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        // White background, then draw the source image
        editContext?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        editContext?.fill(CGRect(origin: .zero, size: sourceSize))
        editContext?.draw(cg, in: CGRect(origin: .zero, size: sourceSize))
        
        saveUndoState()
        notifyImageUpdate()
        needsDisplay = true
    }
    
    // MARK: - Drawing
    
    // NON-FLIPPED: origin at bottom-left, Y increases upward — same as CGContext
    override var isFlipped: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let editImage = editContext?.makeImage() else { return }
        
        let drawRect = imageRect()
        
        // Both the view context and editContext share bottom-left origin,
        // so context.draw() renders the image right-side-up with no transform needed.
        context.draw(editImage, in: drawRect)
        
        // Draw brush cursor
        if let mouseLocation = currentMouseLocation {
            let scaleFactor = drawRect.width / sourceSize.width
            let brushRadius = brushSize * scaleFactor / 2
            
            context.setStrokeColor(NSColor(white: 0.3, alpha: 0.6).cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: CGRect(
                x: mouseLocation.x - brushRadius,
                y: mouseLocation.y - brushRadius,
                width: brushRadius * 2,
                height: brushRadius * 2
            ))
            
            context.setFillColor(NSColor(white: 1.0, alpha: 0.3).cgColor)
            context.fillEllipse(in: CGRect(
                x: mouseLocation.x - brushRadius,
                y: mouseLocation.y - brushRadius,
                width: brushRadius * 2,
                height: brushRadius * 2
            ))
        }
    }
    
    // MARK: - Coordinate Mapping
    
    private func imageRect() -> CGRect {
        let viewSize = bounds.size
        guard sourceSize.width > 0 && sourceSize.height > 0 else { return .zero }
        
        let imageAspect = sourceSize.width / sourceSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var drawWidth: CGFloat
        var drawHeight: CGFloat
        
        if imageAspect > viewAspect {
            drawWidth = viewSize.width
            drawHeight = viewSize.width / imageAspect
        } else {
            drawHeight = viewSize.height
            drawWidth = viewSize.height * imageAspect
        }
        
        let x = (viewSize.width - drawWidth) / 2
        let y = (viewSize.height - drawHeight) / 2
        
        let baseRect = CGRect(x: x, y: y, width: drawWidth, height: drawHeight)
        
        return CGRect(
            x: baseRect.origin.x * zoomScale + panOffset.x,
            y: baseRect.origin.y * zoomScale + panOffset.y,
            width: baseRect.width * zoomScale,
            height: baseRect.height * zoomScale
        )
    }
    
    /// Maps a view coordinate to an image coordinate.
    /// Both view (non-flipped) and CGContext have bottom-left origin → direct mapping, no flip.
    private func viewPointToImagePoint(_ viewPoint: CGPoint) -> CGPoint? {
        let rect = imageRect()
        guard rect.contains(viewPoint) else { return nil }
        
        let normalizedX = (viewPoint.x - rect.minX) / rect.width
        let normalizedY = (viewPoint.y - rect.minY) / rect.height
        
        return CGPoint(
            x: normalizedX * sourceSize.width,
            y: normalizedY * sourceSize.height
        )
    }
    
    // MARK: - Mouse Events
    
    private var currentMouseLocation: CGPoint?
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
    
    override func mouseMoved(with event: NSEvent) {
        currentMouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.push()
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        currentMouseLocation = nil
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        isDrawing = true
        let viewPoint = convert(event.locationInWindow, from: nil)
        currentMouseLocation = viewPoint
        guard let imagePoint = viewPointToImagePoint(viewPoint) else { return }
        lastImagePoint = imagePoint
        
        editContext?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        editContext?.fillEllipse(in: CGRect(
            x: imagePoint.x - brushSize / 2,
            y: imagePoint.y - brushSize / 2,
            width: brushSize,
            height: brushSize
        ))
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDrawing {
            let viewPoint = convert(event.locationInWindow, from: nil)
            currentMouseLocation = viewPoint
            guard let imagePoint = viewPointToImagePoint(viewPoint) else { return }
            
            if let lastPoint = lastImagePoint {
                editContext?.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                editContext?.setLineWidth(brushSize)
                editContext?.setLineCap(.round)
                editContext?.setLineJoin(.round)
                
                editContext?.beginPath()
                editContext?.move(to: lastPoint)
                editContext?.addLine(to: imagePoint)
                editContext?.strokePath()
            }
            lastImagePoint = imagePoint
            needsDisplay = true
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDrawing = false
        lastImagePoint = nil
        saveUndoState()
        notifyImageUpdate()
    }
    
    // MARK: - Zooming & Panning Support
    
    override func magnify(with event: NSEvent) {
        applyZoom(delta: event.magnification, center: convert(event.locationInWindow, from: nil))
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            let zoomDelta = event.scrollingDeltaY * 0.01
            applyZoom(delta: zoomDelta, center: convert(event.locationInWindow, from: nil))
        } else {
            panOffset.x += event.scrollingDeltaX
            panOffset.y += event.scrollingDeltaY
            
            if zoomScale <= 1.0 {
                panOffset = .zero
            }
            needsDisplay = true
        }
    }
    
    private func applyZoom(delta: CGFloat, center: CGPoint) {
        let newZoom = max(1.0, min(15.0, zoomScale + delta))
        if newZoom == zoomScale { return }
        
        let oldScale = zoomScale
        zoomScale = newZoom
        
        let scaleRatio = zoomScale / oldScale
        panOffset.x = center.x - (center.x - panOffset.x) * scaleRatio
        panOffset.y = center.y - (center.y - panOffset.y) * scaleRatio
        
        if zoomScale <= 1.0 {
            panOffset = .zero
        }
        
        needsDisplay = true
    }
    
    // Removed single-point paint method in favor of stroke interpolation
    
    // MARK: - Undo
    
    private func saveUndoState() {
        guard let image = editContext?.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            return
        }
        undoStack.append(data)
        if undoStack.count > 30 {
            undoStack.removeFirst()
        }
    }
    
    func undo() {
        guard undoStack.count > 1 else { return }
        undoStack.removeLast()
        
        guard let data = undoStack.last,
              let rep = NSBitmapImageRep(data: data),
              let cgImage = rep.cgImage else { return }
        
        // Restore the edit context from the previous state
        editContext?.clear(CGRect(origin: .zero, size: sourceSize))
        editContext?.draw(cgImage, in: CGRect(origin: .zero, size: sourceSize))
        needsDisplay = true
        notifyImageUpdate()
    }
    
    // MARK: - Export
    
    private func notifyImageUpdate() {
        guard let cgImage = editContext?.makeImage() else { return }
        let nsImage = NSImage(cgImage: cgImage, size: sourceSize)
        onImageUpdate?(nsImage)
    }
    
    // MARK: - Keyboard
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
            undo()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - NSColor extension for design system

extension NSColor {
    static var csAccent: NSColor {
        NSColor(red: 90/255, green: 200/255, blue: 173/255, alpha: 1.0)
    }
}

import SwiftUI

struct ProgressOverlay: View {
    let message: String
    var progress: Double? = nil // nil = indeterminate
    
    var body: some View {
        ZStack {
            // Frosted glass background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: CSSpacing.lg) {
                if let progress = progress {
                    // Determinate progress
                    ZStack {
                        Circle()
                            .stroke(Color.csBorder, lineWidth: 4)
                            .frame(width: 56, height: 56)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.csAccent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.csCaption)
                            .foregroundStyle(Color.csTextPrimary)
                    }
                } else {
                    // Indeterminate spinner
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.csAccent)
                }
                
                Text(message)
                    .font(.csBody)
                    .foregroundStyle(Color.csTextSecondary)
            }
            .padding(CSSpacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CSRadius.large, style: .continuous)
                    .fill(Color.csSurface)
                    .shadow(color: CSShadow.elevated.color, radius: CSShadow.elevated.radius)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

// MARK: - Success Banner

struct SuccessBanner: View {
    let message: String
    var filePath: String? = nil
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: CSSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.csSuccess.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.csSuccess)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.csBody)
                    .foregroundStyle(Color.csTextPrimary)
                
                if let path = filePath {
                    Text(path)
                        .font(.csSmall)
                        .foregroundStyle(Color.csTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.csTextTertiary)
                        .padding(6)
                        .background(Color.csSurfaceSecondary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(CSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                .fill(Color.csSuccess.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                        .strokeBorder(Color.csSuccess.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

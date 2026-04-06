import SwiftUI

struct ActionButton: View {
    let title: String
    let icon: String
    let style: ButtonStyleType
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    enum ButtonStyleType {
        case primary
        case secondary
        case danger
    }
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            action()
        }) {
            HStack(spacing: CSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(style == .primary ? .white : Color.csAccent)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(title)
                    .font(.csButton)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, CSSpacing.lg)
            .padding(.vertical, CSSpacing.sm + 2)
            .frame(minWidth: 140)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: style == .secondary ? 1.5 : 0)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .disabled(isDisabled || isLoading)
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return isHovered ? Color.csAccentHover : Color.csAccent
        case .danger: return .white
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isHovered ? Color.csAccentHover : Color.csAccent
        case .secondary:
            return isHovered ? Color.csAccentLight : Color.clear
        case .danger:
            return isHovered ? Color.csDanger.opacity(0.85) : Color.csDanger
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .secondary: return Color.csAccent.opacity(0.4)
        case .danger: return .clear
        }
    }
}

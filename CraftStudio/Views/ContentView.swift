import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem = .vectorize
    @StateObject private var updateService = UpdateService()
    
    var body: some View {
        NavigationSplitView {
            SidebarContent(selectedItem: $selectedItem, updateService: updateService)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            DetailContent(selectedItem: selectedItem)
        }
        .background(Color.csBackground)
        .task {
            await updateService.checkForUpdates()
        }
    }
}

// MARK: - Sidebar

struct SidebarContent: View {
    @Binding var selectedItem: SidebarItem
    @ObservedObject var updateService: UpdateService
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo / App Name
            VStack(spacing: CSSpacing.xs) {
                Image(systemName: "scissors")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.csAccent)
                
                Text("CraftStudio")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.csTextPrimary)
            }
            .padding(.top, CSSpacing.lg)
            .padding(.bottom, CSSpacing.xl)
            
            // Navigation Items
            VStack(spacing: CSSpacing.xs) {
                ForEach(SidebarItem.allCases) { item in
                    SidebarButton(
                        item: item,
                        isSelected: selectedItem == item
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedItem = item
                        }
                    }
                }
            }
            .padding(.horizontal, CSSpacing.md)
        
            Spacer()

            HStack(alignment: .center, spacing: CSSpacing.sm) {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                Text("v\(appVersion)")
                    .font(.csSmall)
                    .foregroundStyle(Color.csTextTertiary)
                
                if updateService.isUpdateAvailable {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.orange)
                        .font(.system(size: 10))
                        .help("Une mise à jour (v\(updateService.latestVersionString)) est disponible !")
                }
            }
            .padding(.bottom, CSSpacing.sm)
            
            if updateService.isUpdateAvailable, let url = updateService.latestReleaseURL {
                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Text("Mettre à jour")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.bottom, CSSpacing.md)
            } else {
                Button("Vérifier les mises à jour") {
                    Task {
                        await updateService.checkForUpdates(explicit: true)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(Color.csTextTertiary)
                .padding(.bottom, CSSpacing.md)
            }
        }
        .background(Color.csSurface)
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: CSSpacing.sm + 2) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.csAccent : Color.csTextSecondary)
                    .frame(width: 24)
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color.csTextPrimary : Color.csTextSecondary)
                
                Spacer()
            }
            .padding(.horizontal, CSSpacing.md)
            .padding(.vertical, CSSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: CSRadius.small, style: .continuous)
                    .fill(isSelected ? Color.csAccentLight : (isHovered ? Color.csSurfaceSecondary : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Detail Content

struct DetailContent: View {
    let selectedItem: SidebarItem
    
    var body: some View {
        Group {
            switch selectedItem {
            case .vectorize:
                VectorizeView()
            case .eraser:
                EraserView()
            case .converter:
                ConverterView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.csBackground)
    }
}

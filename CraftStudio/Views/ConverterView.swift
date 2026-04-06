import SwiftUI

struct ConverterView: View {
    @State private var youtubeURL: String = ""
    @State private var isDownloading = false
    @State private var resultTitle: String?
    @State private var resultPath: String?
    @State private var errorMessage: String?
    @State private var ytDlpAvailable: Bool = true
    
    private let service = AudioConversionService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: CSSpacing.xl) {
                    if !ytDlpAvailable {
                        installBanner
                    }
                    
                    if resultTitle == nil {
                        urlInputCard
                    } else {
                        resultCard
                    }
                }
                .padding(CSSpacing.xl)
            }
            
            // Banners
            VStack(spacing: CSSpacing.sm) {
                if let success = resultTitle {
                    SuccessBanner(
                        message: "Audio extrait : \(success)",
                        filePath: resultPath,
                        onDismiss: { withAnimation { resultTitle = nil; resultPath = nil } }
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
        .onAppear { ytDlpAvailable = service.isYtDlpAvailable() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Convertir Audio")
                    .font(.csTitle)
                    .foregroundStyle(Color.csTextPrimary)
                Text("Extrayez l'audio d'une vidéo YouTube en MP3")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
            }
            Spacer()
            if resultTitle != nil {
                Button(action: reset) {
                    HStack(spacing: CSSpacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Nouvelle conversion")
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
    
    // MARK: - URL Input Card
    
    private var urlInputCard: some View {
        VStack(spacing: CSSpacing.lg) {
            // YouTube icon
            ZStack {
                Circle()
                    .fill(Color.csSurfaceSecondary)
                    .frame(width: 72, height: 72)
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.csAccent)
            }
            
            VStack(spacing: CSSpacing.xs) {
                Text("Collez une URL YouTube")
                    .font(.csHeadline)
                    .foregroundStyle(Color.csTextPrimary)
                Text("L'audio sera extrait et converti en MP3")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
            }
            
            // URL text field
            HStack(spacing: CSSpacing.sm) {
                Image(systemName: "link")
                    .foregroundStyle(Color.csTextSecondary)
                    .font(.system(size: 14))
                
                // Utilisation d'une ZStack pour créer un placeholder 100% contrôlable
                ZStack(alignment: .leading) {
                    if youtubeURL.isEmpty {
                        Text(verbatim: "https://www.youtube.com/watch?=...")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Color.csTextSecondary) // <-- Couleur de votre placeholder
                    }
                    
                    TextField("", text: $youtubeURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.csTextPrimary) // <-- Couleur du texte tapé
                }
                
                if !youtubeURL.isEmpty {
                    Button(action: { youtubeURL = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.csTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(CSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                    .fill(Color.csSurfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                    .strokeBorder(Color.csBorder, lineWidth: 1)
            )
            
            // Convert button
            if isDownloading {
                VStack(spacing: CSSpacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Téléchargement en cours...")
                        .font(.csCaption)
                        .foregroundStyle(Color.csTextSecondary)
                }
                .padding(.vertical, CSSpacing.lg)
            } else {
                ActionButton(
                    title: "Convertir en MP3",
                    icon: "arrow.down.circle",
                    style: .primary,
                    isDisabled: youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !ytDlpAvailable
                ) {
                    startDownload()
                }
            }
        }
        .padding(CSSpacing.xl)
        .csCard()
    }
    
    // MARK: - Result Card
    
    private var resultCard: some View {
        VStack(spacing: CSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.csAccent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.csAccent)
            }
            
            VStack(spacing: CSSpacing.xs) {
                Text(resultTitle ?? "")
                    .font(.csHeadline)
                    .foregroundStyle(Color.csTextPrimary)
                    .multilineTextAlignment(.center)
                
                if let path = resultPath {
                    Text(path)
                        .font(.csCaption)
                        .foregroundStyle(Color.csTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            HStack(spacing: CSSpacing.md) {
                ActionButton(title: "Ouvrir dans Finder", icon: "folder", style: .secondary) {
                    if let path = resultPath {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
                ActionButton(title: "Nouvelle conversion", icon: "arrow.counterclockwise", style: .primary) {
                    reset()
                }
            }
        }
        .padding(CSSpacing.xl)
        .csCard()
    }
    
    // MARK: - Install Banner
    
    private var installBanner: some View {
        HStack(spacing: CSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("yt-dlp requis")
                    .font(.csBody.bold())
                    .foregroundStyle(Color.csTextPrimary)
                Text("Installez-le avec : brew install yt-dlp")
                    .font(.csCaption)
                    .foregroundStyle(Color.csTextSecondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(CSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
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
                Image(systemName: "xmark").foregroundStyle(Color.csTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(CSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: CSRadius.medium, style: .continuous)
                .fill(Color.csDanger.opacity(0.08))
        )
    }
    
    // MARK: - Actions
    
    private func startDownload() {
        errorMessage = nil
        isDownloading = true
        
        Task {
            do {
                let result = try await service.downloadAudio(from: youtubeURL)
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        resultTitle = result.title
                        resultPath = result.url.path
                        isDownloading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isDownloading = false
                }
            }
        }
    }
    
    private func reset() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            youtubeURL = ""
            resultTitle = nil
            resultPath = nil
            errorMessage = nil
            isDownloading = false
        }
    }
}

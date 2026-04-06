import Foundation

/// Service for downloading audio from YouTube URLs using yt-dlp
class AudioConversionService {
    
    static let shared = AudioConversionService()
    
    enum DownloadError: LocalizedError {
        case ytDlpNotFound
        case invalidURL
        case downloadFailed(String)
        case noOutputFile
        
        var errorDescription: String? {
            switch self {
            case .ytDlpNotFound:
                return "yt-dlp n'est pas installé.\nInstallez-le avec : brew install yt-dlp"
            case .invalidURL:
                return "L'URL fournie n'est pas valide."
            case .downloadFailed(let msg):
                return "Échec du téléchargement : \(msg)"
            case .noOutputFile:
                return "Le fichier audio n'a pas été trouvé après la conversion."
            }
        }
    }
    
    /// Check if yt-dlp is available on the system
    func isYtDlpAvailable() -> Bool {
        findYtDlp() != nil
    }
    
    /// Download audio from a YouTube URL and save as MP3 in Downloads
    func downloadAudio(from urlString: String) async throws -> (url: URL, title: String) {
        guard let ytDlpPath = findYtDlp() else {
            throw DownloadError.ytDlpNotFound
        }
        
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("youtu") || trimmed.contains("http") else {
            throw DownloadError.invalidURL
        }
        
        // Create a temp directory for the download
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let outputTemplate = tempDir.appendingPathComponent("%(title)s.%(ext)s").path
        
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytDlpPath)
            process.arguments = [
                "-x",                       // extract audio
                "--audio-format", "mp3",    // convert to MP3
                "--audio-quality", "0",     // best quality
                "--no-playlist",            // single video only
                "-o", outputTemplate,       // output path
                trimmed                     // the URL
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            
            // Read all output (prevents pipe buffer overflow)
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                // Extract meaningful error
                let lines = output.components(separatedBy: "\n")
                let errorLine = lines.first(where: { $0.contains("ERROR") }) ?? output.prefix(300).description
                throw DownloadError.downloadFailed(errorLine)
            }
            
            // Find the MP3 file in the temp directory
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let mp3File = files.first(where: { $0.pathExtension.lowercased() == "mp3" }) else {
                throw DownloadError.noOutputFile
            }
            
            // Move to Downloads
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            var destURL = downloadsDir.appendingPathComponent(mp3File.lastPathComponent)
            
            // Avoid overwriting existing files
            var counter = 1
            while FileManager.default.fileExists(atPath: destURL.path) {
                let name = mp3File.deletingPathExtension().lastPathComponent
                destURL = downloadsDir.appendingPathComponent("\(name) (\(counter)).mp3")
                counter += 1
            }
            
            try FileManager.default.moveItem(at: mp3File, to: destURL)
            
            // Clean up temp directory
            try? FileManager.default.removeItem(at: tempDir)
            
            let title = destURL.deletingPathExtension().lastPathComponent
            return (url: destURL, title: title)
        }.value
    }
    
    // Cancel support
    private var currentProcess: Process?
    
    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }
    
    // MARK: - Find yt-dlp
    
    private func findYtDlp() -> String? {
        let paths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            "\(NSHomeDirectory())/.local/bin/yt-dlp"
        ]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }
}

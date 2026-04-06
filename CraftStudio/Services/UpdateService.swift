import Foundation
import Combine
import SwiftUI

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let name: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case name
        case body
    }
}

// MARK: - Update Service
@MainActor
class UpdateService: ObservableObject {
    @Published var isUpdateAvailable: Bool = false
    @Published var latestReleaseURL: URL?
    @Published var latestVersionString: String = ""
    @Published var isCheckingForUpdates: Bool = false
    
    private let githubRepoPath = "NolanNtrg/CraftStudio"
    
    func checkForUpdates(explicit: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        defer { isCheckingForUpdates = false }
        
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepoPath)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if explicit { print("UpdateService: Failed to fetch release data (Status non-200).") }
                return
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = cleanVersion(release.tagName)
            let currentVersion = cleanVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            
            if isNewerVersion(latest: latestVersion, current: currentVersion) {
                self.latestVersionString = latestVersion
                self.latestReleaseURL = URL(string: release.htmlUrl)
                self.isUpdateAvailable = true
            } else {
                if explicit {
                    print("UpdateService: Application is up to date (Current: \(currentVersion), Latest: \(latestVersion))")
                }
            }
            
        } catch {
            if explicit {
                print("UpdateService: Error fetching updates: \(error.localizedDescription)")
            }
        }
    }
    
    /// Removes 'v' from version strings like 'v1.0.1' -> '1.0.1'
    private func cleanVersion(_ version: String) -> String {
        return version.lowercased().replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Simple version comparison
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(latestComponents.count, currentComponents.count) {
            let l = i < latestComponents.count ? latestComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}

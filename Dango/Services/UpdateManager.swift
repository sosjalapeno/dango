import Foundation
import Combine
import os

@MainActor
final class UpdateManager: ObservableObject {

    static let shared = UpdateManager()

    @Published private(set) var isChecking = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var releaseURL: URL?

    private let logger = Logger(subsystem: "com.mateusz.dango", category: "updates")
    private let releasesAPIURL = URL(string: "https://api.github.com/repos/sosjalapeno/dango/releases/latest")!
    private let latestReleaseURL = URL(string: "https://github.com/sosjalapeno/dango/releases/latest")!
    private var latestVersion = ""

    private init() {}

    func checkForUpdates() async {
        guard !isChecking else { return }

        isChecking = true
        updateAvailable = false
        releaseURL = nil
        defer { isChecking = false }

        do {
            var request = URLRequest(url: releasesAPIURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Dango", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                logger.error("GitHub releases request failed with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                logger.error("GitHub releases response missing tag_name")
                return
            }

            let remoteVersion = normalizeVersion(tagName)
            latestVersion = remoteVersion

            guard isNewerVersion(remoteVersion, than: localBundleVersion) else {
                logger.info("App is up to date (local: \(self.localBundleVersion, privacy: .public), remote: \(remoteVersion, privacy: .public))")
                return
            }

            updateAvailable = true
            releaseURL = latestReleaseURL
        } catch {
            logger.error("Update check failed: \(error.localizedDescription)")
        }
    }

    private var localBundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private func normalizeVersion(_ version: String) -> String {
        if version.hasPrefix("v") || version.hasPrefix("V") {
            return String(version.dropFirst())
        }
        return version
    }

    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let localComponents = local.split(separator: ".").compactMap { Int($0) }
        let count = max(remoteComponents.count, localComponents.count)

        for index in 0..<count {
            let remotePart = index < remoteComponents.count ? remoteComponents[index] : 0
            let localPart = index < localComponents.count ? localComponents[index] : 0
            if remotePart > localPart { return true }
            if remotePart < localPart { return false }
        }
        return false
    }
}

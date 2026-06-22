import Foundation

/// App-wide constants and paths, kept in one place.
enum AppInfo {
    static let name = "Shell Drive"
    static let iconResource = "ShellDrive"            // ShellDrive.icns in Resources
    private static let supportFolderName = "ShellDrive"

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// `~/Library/Application Support/ShellDrive` — data lives here, outside the
    /// app bundle, so it survives app deletion/updates.
    static var dataFolderURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(supportFolderName, isDirectory: true)
    }

    static var dataFileURL: URL {
        dataFolderURL.appendingPathComponent("drive.json")
    }
}

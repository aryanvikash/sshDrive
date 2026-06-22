import Foundation

/// Generic example tree seeded on first launch (no personal data).
enum SampleData {
    static let tree: [DriveNode] = [
        .folder("Examples", [
            .folder("Servers", [
                .command("Dev server", "ssh user@dev.example.com"),
                .command("Staging server", "ssh user@staging.example.com"),
                .command("Production server", "ssh user@prod.example.com"),
            ]),
            .folder("Local", [
                .command("Redis CLI", "redis-cli -h 127.0.0.1 -p 6379"),
                .command("Tail app logs", "tail -f /var/log/app.log"),
            ]),
        ]),
        .folder("Snippets", [
            .command("List ports in use", "lsof -i -P -n | grep LISTEN"),
            .command("Disk usage", "du -sh * | sort -h"),
        ]),
    ]
}

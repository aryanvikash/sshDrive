import SwiftUI

/// Settings page: default terminal, launch-at-login, data folder, and about.
struct SettingsView: View {
    @EnvironmentObject private var store: DriveStore
    let onClose: () -> Void
    let onToast: (String) -> Void

    @State private var terminalID = TerminalPreference.bundleID
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Settings", onBack: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    generalSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        SettingsSection("GENERAL") {
            terminalRow
            Divider().padding(.leading, 40)
            SettingsRow(icon: "power", title: "Launch at Login",
                        subtitle: "Open \(AppInfo.name) when you log in") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .onChange(of: launchAtLogin) { _, on in launchAtLogin = LoginItem.setEnabled(on) }
            }
        }
    }

    private var dataSection: some View {
        SettingsSection("DATA") {
            Button(action: reloadFromDisk) {
                SettingsRow(icon: "arrow.clockwise", title: "Reload from Disk",
                            subtitle: "Re-read drive.json after editing it manually") {
                    EmptyView()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 40)
            Button(action: revealDataFolder) {
                SettingsRow(icon: "folder", title: "Reveal Data Folder",
                            subtitle: AppInfo.dataFolderURL.path) {
                    Image(systemName: "arrow.up.forward.app").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func reloadFromDisk() {
        onToast(store.reload() ? "Reloaded from disk" : "Couldn't read drive.json")
    }

    private var aboutSection: some View {
        SettingsSection("ABOUT") {
            HStack(spacing: 10) {
                AppBadge()
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppInfo.name).font(.system(size: 13, weight: .semibold))
                    Text("Version \(AppInfo.version)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    private var terminalRow: some View {
        SettingsRow(icon: "terminal", title: "Default Terminal", subtitle: "Used for Paste & Run") {
            Menu {
                Picker("Terminal", selection: $terminalID) {
                    ForEach(TerminalCatalog.sortedByAvailability) { terminal in
                        Text(TerminalCatalog.isInstalled(terminal.id)
                             ? terminal.name : "\(terminal.name) (not installed)")
                            .tag(terminal.id)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    Text(TerminalCatalog.name(for: terminalID)).font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .onChange(of: terminalID) { _, new in TerminalPreference.bundleID = new }
        }
    }

    private func revealDataFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppInfo.dataFileURL])
    }
}

// MARK: - Reusable rows

/// A titled, rounded group of setting rows.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold)).tracking(0.6)
                .foregroundStyle(.secondary).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1))
        }
    }
}

/// A row with an icon, title/subtitle, and a trailing control.
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

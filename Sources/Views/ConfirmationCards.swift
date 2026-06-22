import SwiftUI

/// Warns before executing a command in a terminal.
struct RunConfirmCard: View {
    let node: DriveNode
    let terminalName: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConfirmHeader(icon: "exclamationmark.triangle.fill", tint: .orange,
                          title: "Run in \(terminalName)?",
                          subtitle: "This executes the command immediately.")

            Text(node.command)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .inputFieldBackground()

            ConfirmButtons(confirmTitle: "Run", tint: .orange,
                           onCancel: onCancel, onConfirm: onConfirm)
        }
        .modalCard()
    }
}

/// Warns before moving a node (and its subtree) to the recycle bin.
struct DeleteConfirmCard: View {
    let node: DriveNode
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var childCount: Int {
        func count(_ list: [DriveNode]) -> Int {
            list.reduce(0) { $0 + 1 + ($1.children.map(count) ?? 0) }
        }
        return count(node.children ?? [])
    }

    private var subtitle: String {
        guard node.isFolder else { return "This command will be moved to Trash." }
        return childCount == 0
            ? "This folder will be moved to Trash."
            : "This folder and its \(childCount) item\(childCount == 1 ? "" : "s") will be moved to Trash."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ConfirmHeader(icon: node.isFolder ? "folder.fill" : "trash.fill", tint: .red,
                          title: "Delete “\(node.name)”?", subtitle: subtitle)

            Text("You can restore it later from the Trash.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)

            ConfirmButtons(confirmTitle: "Delete", tint: .red,
                           onCancel: onCancel, onConfirm: onConfirm)
        }
        .modalCard()
    }
}

// MARK: - Shared pieces

private struct ConfirmHeader: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.17)).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ConfirmButtons: View {
    let confirmTitle: String
    let tint: Color
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
    }
}

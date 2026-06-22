import SwiftUI

/// The recycle bin: restore or permanently delete trashed items, or empty it.
struct TrashView: View {
    @EnvironmentObject private var store: DriveStore
    let onClose: () -> Void
    let onToast: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Recycle Bin", onBack: onClose) {
                Button { store.emptyTrash() } label: {
                    Text("Empty").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(store.trash.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                }
                .buttonStyle(.plain)
                .disabled(store.trash.isEmpty)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if store.trash.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.trash) { item in
                            TrashRow(
                                item: item,
                                onRestore: {
                                    store.restore(item.id)
                                    onToast("Restored “\(item.node.name)”")
                                },
                                onDelete: { store.deleteForever(item.id) })
                        }
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "trash").font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
            Text("Recycle Bin is empty").font(.system(size: 13, weight: .medium))
            Text("Deleted commands appear here").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

private struct TrashRow: View {
    let item: TrashItem
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    private var node: DriveNode { item.node }

    var body: some View {
        HStack(spacing: 8) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(node.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(node.isFolder ? "Folder" : node.command)
                    .font(.system(size: 10.5, design: node.isFolder ? .default : .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if hovering {
                actionButton("arrow.uturn.backward", "Restore", .green, onRestore)
                actionButton("xmark", "Delete forever", .red, onDelete)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.08) : Color.clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .contextMenu {
            Button { onRestore() } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete Forever", systemImage: "trash") }
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(node.isFolder ? AnyShapeStyle(Color.primary.opacity(0.10))
                                    : AnyShapeStyle(Theme.commandGradient.opacity(0.7)))
                .frame(width: 22, height: 22)
            if node.isFolder {
                Image(systemName: "folder").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Text("$_").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        }
    }

    private func actionButton(_ icon: String, _ help: String, _ tint: Color,
                              _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tint.opacity(0.15)))
        }
        .buttonStyle(.plain).help(help)
    }
}

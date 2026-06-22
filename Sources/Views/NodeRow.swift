import SwiftUI
import UniformTypeIdentifiers

/// One row of the command tree, rendered recursively for folders. Supports
/// hover actions, a context menu, and drag-and-drop (move into folders / reorder).
struct NodeRow: View {
    /// Callbacks the row invokes; owned by `RootView`.
    struct Actions {
        let run: (DriveNode) -> Void
        let runShell: (DriveNode) -> Void
        let copy: (DriveNode) -> Void
        let edit: (DriveNode) -> Void
        let delete: (DriveNode) -> Void
        let addCommand: (DriveNode) -> Void
        let addFolder: (DriveNode) -> Void
    }

    @EnvironmentObject private var store: DriveStore
    let node: DriveNode
    let level: Int
    let forceExpanded: Bool
    let actions: Actions

    @State private var hovering = false
    @State private var dropTargeted = false

    private var expanded: Bool { forceExpanded || node.isExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            row
            if node.isFolder, expanded, let children = node.children {
                ForEach(children) { child in
                    NodeRow(node: child, level: level + 1, forceExpanded: forceExpanded, actions: actions)
                }
            }
        }
    }

    // MARK: - Row

    private var row: some View {
        HStack(spacing: 8) {
            disclosure
            icon
            labels
            Spacer(minLength: 4)
            if node.isFolder { childCountBadge }
            if hovering { quickActions }
        }
        .padding(.vertical, node.isFolder ? 6 : 5)
        .padding(.trailing, 8)
        .padding(.leading, CGFloat(level) * 15 + 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture(perform: primaryAction)
        .onDrag { NSItemProvider(object: node.id.uuidString as NSString) }
        .onDrop(of: [.text], isTargeted: $dropTargeted) { providers in
            // Folder → move inside; command → reorder (drop places before it).
            NodeRow.handleDrop(providers, into: node.isFolder ? node.id : nil,
                               before: node.isFolder ? nil : node.id, store: store)
        }
        .help(node.isFolder ? node.name : node.command)
        .contextMenu { contextMenu }
    }

    private func primaryAction() {
        if node.isFolder {
            withAnimation(.easeOut(duration: 0.18)) { store.toggleExpand(node.id) }
        } else {
            actions.run(node)
        }
    }

    @ViewBuilder private var disclosure: some View {
        if node.isFolder {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 10)
        } else {
            Spacer().frame(width: 10)
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(node.isFolder ? AnyShapeStyle(Color.primary.opacity(0.10))
                                    : AnyShapeStyle(Theme.commandGradient))
                .frame(width: 22, height: 22)
            if node.isFolder {
                Image(systemName: expanded ? "folder.fill" : "folder")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            } else {
                Text("$_").font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(node.name)
                    .font(.system(size: 13, weight: node.isFolder ? .semibold : .medium))
                    .foregroundStyle(.primary).lineLimit(1)
                if !node.isFolder, !node.alias.isEmpty { aliasChip }
            }
            if !node.isFolder, !node.command.isEmpty {
                Text(node.command)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var aliasChip: some View {
        Text(node.alias)
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(Theme.accent.opacity(0.15)))
            .help("Alias: type “\(node.alias)” in a terminal")
    }

    private var childCountBadge: some View {
        Text("\(node.children?.count ?? 0)")
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .opacity(hovering ? 0 : 1)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(dropTargeted ? Theme.accent.opacity(0.22)
                               : (hovering ? Color.primary.opacity(0.08) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(dropTargeted ? 0.7 : 0), lineWidth: 1.5)
            )
    }

    // MARK: - Actions

    private var quickActions: some View {
        HStack(spacing: 4) {
            if node.isFolder {
                iconButton("plus", "Add command here") { actions.addCommand(node) }
            } else {
                iconButton("play.fill", "Run in shell") { actions.runShell(node) }
                iconButton("doc.on.doc", "Copy") { actions.copy(node) }
                iconButton("arrow.right.to.line", "Paste to terminal") { actions.run(node) }
            }
            Menu { contextMenu } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .transition(.opacity)
    }

    private func iconButton(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain).help(help)
    }

    @ViewBuilder private var contextMenu: some View {
        if node.isFolder {
            Button { actions.addCommand(node) } label: { Label("Add Command Here", systemImage: "terminal") }
            Button { actions.addFolder(node) } label: { Label("Add Folder Here", systemImage: "folder.badge.plus") }
            Divider()
        } else {
            Button { actions.runShell(node) } label: { Label("Run in Shell…", systemImage: "play.fill") }
            Button { actions.run(node) } label: { Label("Paste to Terminal", systemImage: "arrow.right.to.line") }
            Button { actions.copy(node) } label: { Label("Copy Command", systemImage: "doc.on.doc") }
            Divider()
        }
        Button { actions.edit(node) } label: { Label("Edit…", systemImage: "pencil") }
        Button(role: .destructive) { actions.delete(node) } label: { Label("Delete…", systemImage: "trash") }
    }

    // MARK: - Drag & drop

    /// Reads the dragged node's UUID from the providers and performs the move.
    /// Pass `into` to move inside a folder, or `before` to reorder.
    @discardableResult
    static func handleDrop(_ providers: [NSItemProvider], into parentID: UUID? = nil,
                           before targetID: UUID? = nil, store: DriveStore) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String, let dragged = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                if let targetID { store.move(dragged, beforeNodeID: targetID) }
                else { store.move(dragged, toParent: parentID) }
            }
        }
        return true
    }
}

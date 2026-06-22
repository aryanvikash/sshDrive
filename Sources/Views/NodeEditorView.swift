import SwiftUI

/// What the editor is doing — creating a new node or editing an existing one.
enum EditorTarget: Identifiable {
    case new(parentID: UUID?, isFolder: Bool)
    case edit(DriveNode)

    var id: String {
        switch self {
        case let .new(parentID, isFolder): return "new-\(parentID?.uuidString ?? "root")-\(isFolder)"
        case let .edit(node): return "edit-\(node.id.uuidString)"
        }
    }
}

/// The outcome of the editor, applied by `RootView`.
enum EditorResult {
    case create(parentID: UUID?, node: DriveNode)
    case update(id: UUID, name: String, command: String, alias: String)
    case delete(node: DriveNode)
}

/// Inline editor card for creating/editing a command or folder.
struct NodeEditor: View {
    let target: EditorTarget
    let onClose: () -> Void
    let onCommit: (EditorResult) -> Void

    @State private var name = ""
    @State private var command = ""
    @State private var alias = ""

    private var isFolder: Bool {
        switch target {
        case let .new(_, isFolder): return isFolder
        case let .edit(node): return node.isFolder
        }
    }

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var title: String {
        (isEditing ? "Edit " : "New ") + (isFolder ? "Folder" : "Command")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            field(label: "NAME") {
                TextField(isFolder ? "Folder name" : "e.g. Dev server", text: $name)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .inputFieldBackground()
            }
            if !isFolder {
                commandField
                aliasField
            }
            buttons
        }
        .modalCard()
        .onAppear(perform: loadExistingValues)
    }

    // MARK: - Sections

    private var heading: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFolder ? AnyShapeStyle(Theme.folderGradient)
                                   : AnyShapeStyle(Theme.commandGradient))
                    .frame(width: 28, height: 28)
                Image(systemName: isFolder ? "folder.fill" : "terminal.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            Text(title).font(.system(size: 15, weight: .bold))
        }
    }

    private var commandField: some View {
        field(label: "COMMAND") {
            TextEditor(text: $command)
                .font(.system(size: 12.5, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(height: 76)
                .padding(.horizontal, 7).padding(.vertical, 6)
                .inputFieldBackground()
        }
    }

    private var aliasField: some View {
        field(label: "ALIAS  ·  OPTIONAL") {
            HStack(spacing: 6) {
                Image(systemName: "terminal").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("e.g. devssh", text: $alias)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    .onChange(of: alias) { _, new in alias = AliasManager.sanitize(new) }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .inputFieldBackground()

            Text(alias.isEmpty
                 ? "Set a word to run this command from any terminal."
                 : "Type “\(alias)” in a new terminal to run this. Saved to ~/.zshrc.")
                .font(.system(size: 10))
                .foregroundStyle(alias.isEmpty ? .tertiary : .secondary)
        }
    }

    private var buttons: some View {
        HStack {
            if isEditing {
                Button(role: .destructive) {
                    if case let .edit(node) = target { onCommit(.delete(node: node)) }
                    onClose()
                } label: { Image(systemName: "trash") }
                .help("Delete")
            }
            Spacer()
            Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
            Button("Save", action: commit)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Actions

    private func loadExistingValues() {
        guard case let .edit(node) = target else { return }
        name = node.name
        command = node.command
        alias = node.alias
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        switch target {
        case let .new(parentID, isFolder):
            let node = isFolder
                ? DriveNode(name: trimmedName, children: [])
                : DriveNode(name: trimmedName, command: command, alias: AliasManager.sanitize(alias))
            onCommit(.create(parentID: parentID, node: node))
        case let .edit(node):
            onCommit(.update(id: node.id, name: trimmedName, command: command,
                             alias: AliasManager.sanitize(alias)))
        }
        onClose()
    }
}

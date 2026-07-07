import SwiftUI

/// Whether the env editor is creating a new variable or editing an existing one.
enum EnvEditTarget: Identifiable {
    case new
    case edit(EnvVar)

    var id: String {
        switch self {
        case .new: return "new-env"
        case let .edit(variable): return "edit-\(variable.id.uuidString)"
        }
    }
}

/// Inline card for adding/editing an environment variable.
struct EnvEditorCard: View {
    let target: EnvEditTarget
    let onClose: () -> Void
    let onDelete: () -> Void
    let onCommit: (_ key: String, _ value: String) -> Void

    @State private var key = ""
    @State private var value = ""
    @State private var revealValue = true

    private var isEditing: Bool {
        if case .edit = target { return true }
        return false
    }

    private var canSave: Bool {
        !EnvManager.sanitizeKey(key).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading
            field("KEY") {
                TextField("e.g. OPENAI_API_KEY", text: $key)
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    .onChange(of: key) { _, new in key = EnvManager.sanitizeKey(new) }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .inputFieldBackground()
            }
            field("VALUE") {
                HStack(spacing: 6) {
                    Group {
                        if revealValue {
                            TextField("value", text: $value)
                        } else {
                            SecureField("value", text: $value)
                        }
                    }
                    .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                    Button { revealValue.toggle() } label: {
                        Image(systemName: revealValue ? "eye.slash" : "eye")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .inputFieldBackground()
            }
            Text("Saved to ~/.zshrc. Open a new terminal to use it.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
            buttons
        }
        .modalCard()
        .onAppear(perform: loadExisting)
    }

    private var heading: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.folderGradient).frame(width: 28, height: 28)
                Image(systemName: "curlybraces").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
            Text(isEditing ? "Edit Variable" : "New Variable").font(.system(size: 15, weight: .bold))
        }
    }

    private var buttons: some View {
        HStack {
            if isEditing {
                Button(role: .destructive) { onDelete(); onClose() } label: { Image(systemName: "trash") }
                    .help("Delete")
            }
            Spacer()
            Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
            Button("Save") { commit() }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(!canSave)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
            content()
        }
    }

    private func loadExisting() {
        guard case let .edit(variable) = target else { return }
        key = variable.key
        value = variable.value
        revealValue = !variable.isSecret
    }

    private func commit() {
        guard canSave else { return }
        onCommit(key, value)
        onClose()
    }
}

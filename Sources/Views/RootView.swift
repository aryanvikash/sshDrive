import SwiftUI
import UniformTypeIdentifiers

/// The popover's root: a header, the active page (commands / trash / settings),
/// a footer, and modal overlays for editing and confirmations.
struct RootView: View {
    @EnvironmentObject private var store: DriveStore

    @State private var search = ""
    @State private var page: Page = .commands
    @State private var editorTarget: EditorTarget?
    @State private var envEditTarget: EnvEditTarget?
    @State private var runTarget: DriveNode?
    @State private var deleteTarget: DriveNode?
    @State private var toast: String?
    @State private var rootDropTargeted = false

    private enum Page { case commands, env, trash, settings }

    var body: some View {
        ZStack {
            background
            content
            overlays
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: editorTarget != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: envEditTarget != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: runTarget != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: deleteTarget != nil)
    }

    // MARK: - Layers

    private var background: some View {
        ZStack {
            VisualEffectView(material: .popover).ignoresSafeArea()
            LinearGradient(colors: [Theme.accent.opacity(0.10), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            switch page {
            case .commands: commandsPage
            case .env:      EnvView(onClose: { page = .commands },
                                    onAdd: { envEditTarget = .new },
                                    onEdit: { envEditTarget = .edit($0) },
                                    onToast: showToast)
            case .trash:    TrashView(onClose: { page = .commands }, onToast: showToast)
            case .settings: SettingsView(onClose: { page = .commands }, onToast: showToast)
            }
            footer
        }
        .overlay(alignment: .bottom) { toastBanner }
    }

    @ViewBuilder private var overlays: some View {
        if let target = editorTarget {
            modalOverlay { editorTarget = nil } content: {
                NodeEditor(target: target, onClose: { editorTarget = nil }, onCommit: apply)
                    .environmentObject(store)
            }
        }
        if let target = envEditTarget {
            modalOverlay { envEditTarget = nil } content: {
                EnvEditorCard(
                    target: target,
                    onClose: { envEditTarget = nil },
                    onDelete: { if case let .edit(variable) = target { store.deleteEnv(variable.id) } }
                ) { key, value in
                    switch target {
                    case .new: store.addEnv(key: key, value: value)
                    case let .edit(variable): store.updateEnv(variable.id, key: key, value: value)
                    }
                }
            }
        }
        if let target = runTarget {
            modalOverlay { runTarget = nil } content: {
                RunConfirmCard(node: target,
                               terminalName: TerminalCatalog.name(for: TerminalPreference.bundleID),
                               onCancel: { runTarget = nil },
                               onConfirm: { run(target) })
            }
        }
        if let target = deleteTarget {
            modalOverlay { deleteTarget = nil } content: {
                DeleteConfirmCard(node: target,
                                  onCancel: { deleteTarget = nil },
                                  onConfirm: { confirmDelete(target) })
            }
        }
    }

    private func modalOverlay<Content: View>(onDismiss: @escaping () -> Void,
                                             @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture(perform: onDismiss)
            content()
                .padding(.horizontal, 14)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    // MARK: - Commands page

    private var commandsPage: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let roots = filtered(store.nodes, query: search)
                    if roots.isEmpty {
                        emptyState
                    } else {
                        ForEach(roots) { node in
                            NodeRow(node: node, level: 0, forceExpanded: !search.isEmpty,
                                    actions: rowActions)
                        }
                    }
                    rootDropZone
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.accent.opacity(rootDropTargeted ? 0.5 : 0), lineWidth: 2)
                        .padding(4)
                )
            }
        }
    }

    /// Fills remaining space so dropping in the empty area moves an item to root.
    private var rootDropZone: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(Rectangle())
            .onDrop(of: [.text], isTargeted: $rootDropTargeted) { providers in
                NodeRow.handleDrop(providers, into: nil, store: store)
            }
    }

    private var rowActions: NodeRow.Actions {
        NodeRow.Actions(
            run: paste,
            runShell: { runTarget = $0 },
            copy: copy,
            edit: { editorTarget = .edit($0) },
            delete: { deleteTarget = $0 },
            addCommand: { editorTarget = .new(parentID: $0.id, isFolder: false) },
            addFolder: { editorTarget = .new(parentID: $0.id, isFolder: true) })
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 10) {
            AppBadge(size: 30, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppInfo.name).font(.system(size: 16, weight: .bold))
                Text("\(commandCount(store.nodes)) commands")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: reloadFromDisk) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Reload from disk")
            Menu {
                Button { editorTarget = .new(parentID: nil, isFolder: false) } label: {
                    Label("New Command", systemImage: "terminal")
                }
                Button { editorTarget = .new(parentID: nil, isFolder: true) } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.accent.opacity(0.14)))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Add a command or folder")
        }
        .padding(.horizontal, 14).padding(.top, 16).padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            FooterButton(icon: "curlybraces", title: "Env", active: page == .env) { toggle(.env) }
            FooterButton(icon: "trash", title: "Trash",
                         badge: store.trash.isEmpty ? nil : store.trash.count,
                         active: page == .trash) { toggle(.trash) }
            Spacer()
            FooterButton(icon: "gearshape", active: page == .settings) { toggle(.settings) }
            FooterButton(icon: "power") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
        }
    }

    /// Navigate to `target`, or back to commands if already there.
    private func toggle(_ target: Page) {
        page = (page == target) ? .commands : target
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            TextField("Search name, command, or alias", text: $search)
                .textFieldStyle(.plain).font(.system(size: 13))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary).font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: search.isEmpty ? "terminal" : "magnifyingglass")
                .font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
            Text(search.isEmpty ? "No commands yet" : "No matches")
                .font(.system(size: 13, weight: .medium))
            if search.isEmpty {
                Text("Click + to add your first command")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    @ViewBuilder private var toastBanner: some View {
        if let toast {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12))
                Text(toast).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .padding(.bottom, 56)
            .allowsHitTesting(false)        // never intercept clicks on the footer/list
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    private func paste(_ node: DriveNode) {
        TerminalService.shared.pasteToTerminal(node.command)
        showToast("Pasted “\(node.name)” to terminal")
    }

    private func copy(_ node: DriveNode) {
        TerminalService.shared.copyToClipboard(node.command)
        showToast("Copied “\(node.name)”")
    }

    private func run(_ node: DriveNode) {
        runTarget = nil
        TerminalService.shared.runInTerminal(node.command)
        showToast("Running “\(node.name)” in \(TerminalCatalog.name(for: TerminalPreference.bundleID))")
    }

    private func confirmDelete(_ node: DriveNode) {
        deleteTarget = nil
        store.delete(node.id)
        showToast("Moved “\(node.name)” to Trash")
    }

    private func reloadFromDisk() {
        showToast(store.reload() ? "Reloaded from disk" : "Couldn't read drive.json")
    }

    private func apply(_ result: EditorResult) {
        switch result {
        case let .create(parentID, node): store.add(node, toParent: parentID)
        case let .update(id, name, command, alias):
            store.update(id, name: name, command: command, alias: alias)
        case let .delete(node): deleteTarget = node     // route through confirmation
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.25)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    // MARK: - Derived data

    private func commandCount(_ nodes: [DriveNode]) -> Int {
        nodes.reduce(0) { $0 + ($1.isFolder ? commandCount($1.children ?? []) : 1) }
    }

    /// Filters the tree, keeping folders whose name matches or that contain a match.
    private func filtered(_ nodes: [DriveNode], query: String) -> [DriveNode] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nodes }
        return nodes.compactMap { node in
            if node.isFolder {
                let matches = filtered(node.children ?? [], query: query)
                guard !matches.isEmpty || node.name.lowercased().contains(q) else { return nil }
                var copy = node
                copy.children = matches.isEmpty ? node.children : matches
                return copy
            }
            let haystacks = [node.name, node.command, node.alias].map { $0.lowercased() }
            return haystacks.contains { $0.contains(q) } ? node : nil
        }
    }
}

/// The gradient app badge reused in the header, settings, and elsewhere.
struct AppBadge: View {
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 9

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.commandGradient)
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.97, green: 0.33, blue: 0.47).opacity(0.4), radius: 6, y: 2)
            Image(systemName: "terminal.fill")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

/// A compact, optionally-labelled footer button with an optional count badge.
private struct FooterButton: View {
    let icon: String
    var title: String?
    var badge: Int?
    var active = false
    let action: () -> Void

    var body: some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { action() } } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
                if let title { Text(title).font(.system(size: 11, weight: .medium)) }
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(.red))
                }
            }
            .foregroundStyle(active ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary))
            // Enlarge the hit target and make the whole rectangle clickable so
            // taps in the gaps between icon/label/badge still register.
            .padding(.horizontal, 6).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

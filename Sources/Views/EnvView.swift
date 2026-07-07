import SwiftUI

/// The environment page: a "Managed" list you edit and a read-only "System"
/// snapshot of the live shell environment.
struct EnvView: View {
    @EnvironmentObject private var store: DriveStore
    let onClose: () -> Void
    let onAdd: () -> Void
    let onEdit: (EnvVar) -> Void
    let onToast: (String) -> Void

    private enum Mode { case managed, system }

    @State private var mode: Mode = .managed
    @State private var search = ""
    @State private var systemVars: [EnvVar]?
    @State private var loadingSystem = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("", selection: $mode) {
                Text("Managed").tag(Mode.managed)
                Text("System").tag(Mode.system)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.bottom, 10)

            if showSearch {
                searchBar.padding(.horizontal, 14).padding(.bottom, 10)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    switch mode {
                    case .managed: managedList
                    case .system:  systemList
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 8)
            }
        }
        .onChange(of: mode) { _, new in if new == .system { loadSystemIfNeeded() } }
    }

    // MARK: - Header

    private var header: some View {
        PageHeader(title: "Environment", onBack: onClose) {
            if mode == .managed {
                headerButton("plus", "Add a variable", action: onAdd)
            } else {
                headerButton("arrow.clockwise", "Refresh") { systemVars = nil; loadSystemIfNeeded() }
            }
        }
    }

    private func headerButton(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.accent.opacity(0.14)))
        }
        .buttonStyle(.plain).help(help)
    }

    private var showSearch: Bool {
        mode == .system ? (systemVars?.isEmpty == false) : !store.envVars.isEmpty
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            TextField("Search variables", text: $search)
                .textFieldStyle(.plain).font(.system(size: 13))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).font(.system(size: 13))
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

    // MARK: - Managed list

    private var managedList: some View {
        Group {
            if store.envVars.isEmpty {
                emptyState(icon: "curlybraces", title: "No variables yet",
                           subtitle: "Click + to export your first variable")
            } else {
                ForEach(filter(store.envVars)) { variable in
                    EnvRow(variable: variable, managed: true,
                           onEdit: { onEdit(variable) },
                           onCopy: copy,
                           onAdopt: nil,
                           onDelete: { store.deleteEnv(variable.id) })
                }
            }
        }
    }

    // MARK: - System list

    @ViewBuilder private var systemList: some View {
        if loadingSystem && systemVars == nil {
            HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }.padding(.top, 60)
        } else {
            let managedKeys = Set(store.envVars.map(\.key))
            let vars = filter(systemVars ?? [])
            if vars.isEmpty {
                emptyState(icon: "macwindow", title: "No variables",
                           subtitle: "Couldn't read the shell environment")
            } else {
                ForEach(vars) { variable in
                    EnvRow(variable: variable, managed: managedKeys.contains(variable.key),
                           onEdit: nil,
                           onCopy: copy,
                           onAdopt: managedKeys.contains(variable.key) ? nil : {
                               store.addEnv(key: variable.key, value: variable.value)
                               onToast("Added \(variable.key) to Shell Drive")
                           },
                           onDelete: nil)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 13, weight: .medium))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    // MARK: - Helpers

    private func filter(_ vars: [EnvVar]) -> [EnvVar] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return vars }
        return vars.filter { $0.key.lowercased().contains(q) || $0.value.lowercased().contains(q) }
    }

    private func copy(_ text: String, _ toast: String) {
        TerminalService.shared.copyToClipboard(text)
        onToast(toast)
    }

    private func loadSystemIfNeeded() {
        guard systemVars == nil, !loadingSystem else { return }
        loadingSystem = true
        Task.detached {
            let snapshot = SystemEnv.snapshot()
            await MainActor.run { systemVars = snapshot; loadingSystem = false }
        }
    }
}

// MARK: - Row

private struct EnvRow: View {
    let variable: EnvVar
    let managed: Bool
    let onEdit: (() -> Void)?
    let onCopy: (_ text: String, _ toast: String) -> Void
    let onAdopt: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var hovering = false
    @State private var revealed = false

    private var masked: Bool { variable.isSecret && !revealed }

    private var displayValue: String {
        if variable.value.isEmpty { return "(empty)" }
        return masked ? String(repeating: "•", count: min(12, max(6, variable.value.count))) : variable.value
    }

    var body: some View {
        HStack(spacing: 8) {
            iconBadge
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(variable.key).font(.system(size: 13, weight: .medium, design: .monospaced)).lineLimit(1)
                    if managed { managedChip }
                }
                Text(displayValue)
                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if hovering { actions }
        }
        .padding(.vertical, 5).padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(hovering ? Color.primary.opacity(0.08) : Color.clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onTapGesture { onEdit?() }
        .contextMenu { contextMenu }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(managed ? AnyShapeStyle(Theme.folderGradient.opacity(0.85))
                              : AnyShapeStyle(Color.primary.opacity(0.10)))
                .frame(width: 22, height: 22)
            Image(systemName: variable.isSecret ? "key.fill" : "curlybraces")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(managed ? .white : .secondary)
        }
    }

    private var managedChip: some View {
        Text("managed")
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(Theme.accent.opacity(0.15)))
    }

    private var actions: some View {
        HStack(spacing: 4) {
            if variable.isSecret {
                iconButton(revealed ? "eye.slash" : "eye", revealed ? "Hide" : "Reveal") { revealed.toggle() }
            }
            if let onAdopt { iconButton("plus", "Add to Shell Drive", onAdopt) }
            iconButton("doc.on.doc", "Copy value") { onCopy(variable.value, "Copied \(variable.key)") }
            if let onDelete { iconButton("trash", "Delete", tint: .red, onDelete) }
        }
    }

    @ViewBuilder private var contextMenu: some View {
        Button { onCopy(variable.value, "Copied \(variable.key)") } label: { Label("Copy Value", systemImage: "doc.on.doc") }
        Button { onCopy("$\(variable.key)", "Copied $\(variable.key)") } label: { Label("Copy $\(variable.key)", systemImage: "dollarsign") }
        Button { onCopy("export \(variable.key)=\(ShellConfigManager.quote(variable.value))", "Copied export line") } label: {
            Label("Copy export line", systemImage: "terminal")
        }
        if onEdit != nil || onAdopt != nil || onDelete != nil { Divider() }
        if let onAdopt { Button(action: onAdopt) { Label("Add to Shell Drive", systemImage: "plus") } }
        if let onEdit { Button(action: onEdit) { Label("Edit…", systemImage: "pencil") } }
        if let onDelete { Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") } }
    }

    private func iconButton(_ icon: String, _ help: String, tint: Color = .secondary,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 22, height: 22).background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain).help(help)
    }
}

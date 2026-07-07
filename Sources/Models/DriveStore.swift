import Foundation
import Combine

/// On-disk format: nodes + trash + env vars together. Decodes tolerantly so
/// files written by older versions (missing newer keys) still load.
private struct DriveData: Codable {
    var nodes: [DriveNode]
    var trash: [TrashItem]
    var envVars: [EnvVar]

    init(nodes: [DriveNode], trash: [TrashItem], envVars: [EnvVar]) {
        self.nodes = nodes
        self.trash = trash
        self.envVars = envVars
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try c.decodeIfPresent([DriveNode].self, forKey: .nodes) ?? []
        trash = try c.decodeIfPresent([TrashItem].self, forKey: .trash) ?? []
        envVars = try c.decodeIfPresent([EnvVar].self, forKey: .envVars) ?? []
    }
}

/// The single source of truth for the command tree, recycle bin, and env vars.
/// Persists to JSON in Application Support and keeps `~/.zshrc` in sync on save.
final class DriveStore: ObservableObject {
    @Published private(set) var nodes: [DriveNode] = []
    @Published private(set) var trash: [TrashItem] = []
    @Published private(set) var envVars: [EnvVar] = []

    private let fileURL: URL

    init(fileURL: URL = AppInfo.dataFileURL) {
        self.fileURL = fileURL
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        load()
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(DriveData.self, from: data) {
                nodes = decoded.nodes
                trash = decoded.trash
                envVars = decoded.envVars
                return
            }
            if let legacy = try? decoder.decode([DriveNode].self, from: data) {
                nodes = legacy              // migrate older bare-array files
                save()
                return
            }
        }
        nodes = SampleData.tree
        save()
    }

    /// Re-read the data file from disk (e.g. after a manual edit) and update
    /// state. Does not overwrite the file. Returns false if it can't be parsed.
    @discardableResult
    func reload() -> Bool {
        guard let data = try? Data(contentsOf: fileURL) else { return false }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(DriveData.self, from: data) {
            nodes = decoded.nodes
            trash = decoded.trash
            envVars = decoded.envVars
        } else if let legacy = try? decoder.decode([DriveNode].self, from: data) {
            nodes = legacy
            trash = []
            envVars = []
        } else {
            return false
        }
        ShellConfigManager.sync(aliasLines: AliasManager.lines(from: nodes),
                                envLines: EnvManager.lines(from: envVars))
        return true
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(DriveData(nodes: nodes, trash: trash, envVars: envVars)) {
            try? data.write(to: fileURL, options: .atomic)
        }
        // Keep ~/.zshrc in sync: aliases (from live commands) + env vars.
        ShellConfigManager.sync(aliasLines: AliasManager.lines(from: nodes),
                                envLines: EnvManager.lines(from: envVars))
    }

    // MARK: - Tree mutations

    func add(_ node: DriveNode, toParent parentID: UUID?) {
        insert(node, intoParent: parentID)
        save()
    }

    func update(_ id: UUID, name: String, command: String, alias: String) {
        mutate(id, in: &nodes) { node in
            node.name = name
            if !node.isFolder {
                node.command = command
                node.alias = alias
            }
        }
        save()
    }

    func toggleExpand(_ id: UUID) {
        mutate(id, in: &nodes) { $0.isExpanded.toggle() }
    }

    /// Move a node into a new parent folder (nil = root), appended to the end.
    /// No-ops on invalid moves (onto itself or into its own subtree).
    func move(_ id: UUID, toParent newParentID: UUID?) {
        guard !wouldCreateCycle(moving: id, into: newParentID),
              let (node, _) = extract(id, from: &nodes, parent: nil) else { return }
        insert(node, intoParent: newParentID)
        save()
    }

    /// Reorder: move `id` so it sits immediately before `targetID`.
    func move(_ id: UUID, beforeNodeID targetID: UUID) {
        guard id != targetID,
              !wouldCreateCycle(moving: id, into: targetID),
              let (node, _) = extract(id, from: &nodes, parent: nil) else { return }
        if !insertBefore(targetID, node: node, in: &nodes) {
            nodes.append(node)              // fallback if the target disappeared
        }
        save()
    }

    // MARK: - Recycle bin

    /// Move a node (and its subtree) into the recycle bin.
    func delete(_ id: UUID) {
        if let (node, parentID) = extract(id, from: &nodes, parent: nil) {
            trash.insert(TrashItem(node: node, parentID: parentID), at: 0)
        }
        save()
    }

    /// Put a trashed node back where it came from (or root if its parent is gone).
    func restore(_ id: UUID) {
        guard let index = trash.firstIndex(where: { $0.id == id }) else { return }
        let item = trash.remove(at: index)
        let parent = item.parentID.flatMap { contains($0, in: nodes) ? $0 : nil }
        insert(item.node, intoParent: parent)
        save()
    }

    func deleteForever(_ id: UUID) {
        trash.removeAll { $0.id == id }
        save()
    }

    func emptyTrash() {
        trash.removeAll()
        save()
    }

    // MARK: - Environment variables

    @discardableResult
    func addEnv(key: String, value: String) -> Bool {
        let key = EnvManager.sanitizeKey(key)
        guard !key.isEmpty else { return false }
        envVars.append(EnvVar(key: key, value: value))
        save()
        return true
    }

    @discardableResult
    func updateEnv(_ id: UUID, key: String, value: String) -> Bool {
        let key = EnvManager.sanitizeKey(key)
        guard !key.isEmpty, let index = envVars.firstIndex(where: { $0.id == id }) else { return false }
        envVars[index].key = key
        envVars[index].value = value
        save()
        return true
    }

    func deleteEnv(_ id: UUID) {
        envVars.removeAll { $0.id == id }
        save()
    }

    // MARK: - Recursive helpers

    private func insert(_ node: DriveNode, intoParent parentID: UUID?) {
        guard let parentID else { nodes.append(node); return }
        mutate(parentID, in: &nodes) { parent in
            parent.children = (parent.children ?? []) + [node]
            parent.isExpanded = true
        }
    }

    /// True if moving `id` under `targetID` would nest a folder inside itself.
    private func wouldCreateCycle(moving id: UUID, into targetID: UUID?) -> Bool {
        guard let targetID else { return false }
        if targetID == id { return true }
        if let moving = find(id, in: nodes), let children = moving.children {
            return contains(targetID, in: children)
        }
        return false
    }

    @discardableResult
    private func mutate(_ id: UUID, in list: inout [DriveNode],
                        _ body: (inout DriveNode) -> Void) -> Bool {
        for i in list.indices {
            if list[i].id == id { body(&list[i]); return true }
            if list[i].children != nil, mutate(id, in: &list[i].children!, body) { return true }
        }
        return false
    }

    /// Remove the node with `id`, returning it and its parent's id.
    private func extract(_ id: UUID, from list: inout [DriveNode],
                         parent: UUID?) -> (DriveNode, UUID?)? {
        if let index = list.firstIndex(where: { $0.id == id }) {
            return (list.remove(at: index), parent)
        }
        for i in list.indices where list[i].children != nil {
            if let found = extract(id, from: &list[i].children!, parent: list[i].id) { return found }
        }
        return nil
    }

    @discardableResult
    private func insertBefore(_ targetID: UUID, node: DriveNode, in list: inout [DriveNode]) -> Bool {
        if let index = list.firstIndex(where: { $0.id == targetID }) {
            list.insert(node, at: index)
            return true
        }
        for i in list.indices where list[i].children != nil {
            if insertBefore(targetID, node: node, in: &list[i].children!) { return true }
        }
        return false
    }

    private func find(_ id: UUID, in list: [DriveNode]) -> DriveNode? {
        for node in list {
            if node.id == id { return node }
            if let children = node.children, let found = find(id, in: children) { return found }
        }
        return nil
    }

    private func contains(_ id: UUID, in list: [DriveNode]) -> Bool {
        find(id, in: list) != nil
    }
}

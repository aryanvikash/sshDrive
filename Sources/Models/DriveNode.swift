import Foundation

/// A node in the Shell Drive tree. It is either a **folder** (`children != nil`)
/// or a **command** (`children == nil`, with `command` holding the shell text).
struct DriveNode: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var command: String = ""
    var alias: String = ""              // optional shell alias written to ~/.zshrc
    var children: [DriveNode]? = nil
    var isExpanded: Bool = true

    var isFolder: Bool { children != nil }

    enum CodingKeys: String, CodingKey {
        case id, name, command, alias, children, isExpanded
    }

    init(id: UUID = UUID(), name: String, command: String = "", alias: String = "",
         children: [DriveNode]? = nil, isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.alias = alias
        self.children = children
        self.isExpanded = isExpanded
    }

    /// Tolerant decoding so files written by older versions (missing newer keys)
    /// still load instead of failing and wiping data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        command = try c.decodeIfPresent(String.self, forKey: .command) ?? ""
        alias = try c.decodeIfPresent(String.self, forKey: .alias) ?? ""
        children = try c.decodeIfPresent([DriveNode].self, forKey: .children)
        isExpanded = try c.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
    }

    static func folder(_ name: String, _ children: [DriveNode] = []) -> DriveNode {
        DriveNode(name: name, children: children)
    }

    static func command(_ name: String, _ command: String) -> DriveNode {
        DriveNode(name: name, command: command)
    }
}

/// A deleted node sitting in the recycle bin, remembering where it came from.
struct TrashItem: Identifiable, Codable, Hashable {
    var node: DriveNode
    var parentID: UUID?                 // original parent, for restore (nil = root)
    var id: UUID { node.id }
}

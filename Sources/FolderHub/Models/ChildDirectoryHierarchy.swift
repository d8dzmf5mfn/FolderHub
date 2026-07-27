import Foundation

struct ChildDirectoryHierarchy {
  struct Node: Identifiable, Equatable, Sendable {
    let id: UUID
    let directoryURL: URL
    let parentID: UUID?
  }

  enum Registration {
    case inserted(Node)
    case existing(Node)
  }

  private(set) var nodes: [Node] = []

  mutating func register(
    _ rawURL: URL,
    parentID: UUID?
  ) -> Registration {
    let url = rawURL.standardizedFileURL
    if let existing = nodes.first(where: {
      $0.directoryURL.standardizedFileURL == url
    }) {
      return .existing(existing)
    }

    let node = Node(
      id: UUID(),
      directoryURL: url,
      parentID: parentID
    )
    nodes.append(node)
    return .inserted(node)
  }

  func node(id: UUID) -> Node? {
    nodes.first { $0.id == id }
  }

  func children(of parentID: UUID?) -> [Node] {
    nodes.filter { $0.parentID == parentID }
  }

  mutating func removeSubtree(rootedAt rootID: UUID) -> [Node] {
    var removedIDs: Set<UUID> = [rootID]
    var didAddNode = true

    while didAddNode {
      didAddNode = false
      for node in nodes
      where node.parentID.map(removedIDs.contains) == true
        && !removedIDs.contains(node.id)
      {
        removedIDs.insert(node.id)
        didAddNode = true
      }
    }

    let removed = nodes.filter { removedIDs.contains($0.id) }
    nodes.removeAll { removedIDs.contains($0.id) }
    return Array(removed.reversed())
  }

}

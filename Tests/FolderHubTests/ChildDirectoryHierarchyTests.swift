import Foundation
import Testing

@testable import FolderHub

@Suite("Child directory hierarchy")
struct ChildDirectoryHierarchyTests {
  @Test("Multiple sibling folders remain registered together")
  func keepsSiblingsOpen() {
    var hierarchy = ChildDirectoryHierarchy()
    let first = insertedNode(
      hierarchy.register(
        URL(fileURLWithPath: "/tmp/Projects/Design"),
        parentID: nil
      )
    )
    let second = insertedNode(
      hierarchy.register(
        URL(fileURLWithPath: "/tmp/Projects/Research"),
        parentID: nil
      )
    )

    #expect(hierarchy.nodes.count == 2)
    #expect(hierarchy.children(of: nil).map(\.id) == [first.id, second.id])
  }

  @Test("Closing one branch removes only its descendants")
  func closesOnlyOneSubtree() {
    var hierarchy = ChildDirectoryHierarchy()
    let first = insertedNode(
      hierarchy.register(
        URL(fileURLWithPath: "/tmp/Projects/Design"),
        parentID: nil
      )
    )
    let sibling = insertedNode(
      hierarchy.register(
        URL(fileURLWithPath: "/tmp/Projects/Research"),
        parentID: nil
      )
    )
    let child = insertedNode(
      hierarchy.register(
        URL(fileURLWithPath: "/tmp/Projects/Design/Assets"),
        parentID: first.id
      )
    )

    let removed = hierarchy.removeSubtree(rootedAt: first.id)

    #expect(Set(removed.map(\.id)) == [first.id, child.id])
    #expect(hierarchy.nodes.map(\.id) == [sibling.id])
  }

  @Test("Opening the same directory focuses the existing branch")
  func deduplicatesDirectoryURL() {
    var hierarchy = ChildDirectoryHierarchy()
    let url = URL(fileURLWithPath: "/tmp/Projects/Design")
    let first = insertedNode(hierarchy.register(url, parentID: nil))

    let repeated = hierarchy.register(
      url.appendingPathComponent("..").appendingPathComponent("Design"),
      parentID: nil
    )

    guard case .existing(let existing) = repeated else {
      Issue.record("Expected an existing branch registration")
      return
    }
    #expect(existing.id == first.id)
    #expect(hierarchy.nodes.count == 1)
  }

  private func insertedNode(
    _ registration: ChildDirectoryHierarchy.Registration
  ) -> ChildDirectoryHierarchy.Node {
    guard case .inserted(let node) = registration else {
      Issue.record("Expected a new branch registration")
      return ChildDirectoryHierarchy.Node(
        id: UUID(),
        directoryURL: URL(fileURLWithPath: "/"),
        parentID: nil
      )
    }
    return node
  }
}

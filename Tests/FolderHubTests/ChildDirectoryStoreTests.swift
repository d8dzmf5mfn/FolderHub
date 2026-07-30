import Foundation
import Testing

@testable import FolderHub

@Suite("Child directory store")
@MainActor
struct ChildDirectoryStoreTests {
  @Test("Pin state toggles independently and notifies its window")
  func pinToggle() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ChildDirectoryStore(directoryURL: root)
    var reportedStates: [Bool] = []
    store.onPinChange = { reportedStates.append($0) }

    store.togglePinned()
    store.togglePinned()

    #expect(store.isPinned == false)
    #expect(reportedStates == [true, false])
  }

  @Test("Nested folder count refreshes after additions and removals")
  func nestedFolderCountRefresh() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let child = root.appendingPathComponent("Child", isDirectory: true)
    try FileManager.default.createDirectory(
      at: child,
      withIntermediateDirectories: false
    )

    let store = ChildDirectoryStore(directoryURL: root)
    #expect(
      await waitUntil {
        store.items.first(where: { $0.name == "Child" })?.visibleChildCount
          == 0
      }
    )

    try await Task.sleep(for: .milliseconds(750))
    let nested = child.appendingPathComponent("Nested", isDirectory: true)
    try FileManager.default.createDirectory(
      at: nested,
      withIntermediateDirectories: false
    )

    #expect(
      await waitUntil {
        store.items.first(where: { $0.name == "Child" })?.visibleChildCount
          == 1
      }
    )

    try FileManager.default.removeItem(at: nested)

    #expect(
      await waitUntil {
        store.items.first(where: { $0.name == "Child" })?.visibleChildCount
          == 0
      }
    )
  }

  @Test("Selected sort order survives file system refreshes")
  func sortOrderSurvivesRefresh() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    try Data("a".utf8).write(to: root.appendingPathComponent("Alpha.txt"))
    try Data("z".utf8).write(to: root.appendingPathComponent("Zulu.txt"))

    let store = ChildDirectoryStore(directoryURL: root)
    #expect(
      await waitUntil {
        store.items.map(\.name) == ["Alpha.txt", "Zulu.txt"]
      }
    )

    store.setSortOrder(
      DirectorySortOrder(
        criterion: .name,
        direction: .descending
      )
    )
    #expect(store.items.map(\.name) == ["Zulu.txt", "Alpha.txt"])

    try await Task.sleep(for: .milliseconds(750))
    try Data("m".utf8).write(to: root.appendingPathComponent("Middle.txt"))

    #expect(
      await waitUntil {
        store.items.map(\.name)
          == ["Zulu.txt", "Middle.txt", "Alpha.txt"]
      }
    )
  }

  private func waitUntil(
    _ condition: () -> Bool
  ) async -> Bool {
    for _ in 0..<100 {
      if condition() {
        return true
      }
      try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
  }
}

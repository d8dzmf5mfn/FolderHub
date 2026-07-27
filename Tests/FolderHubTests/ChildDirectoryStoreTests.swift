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
}

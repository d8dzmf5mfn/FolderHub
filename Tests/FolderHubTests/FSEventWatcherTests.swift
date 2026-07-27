import Foundation
import Testing
import XCTest

@testable import FolderHub

@Suite("File system event watcher")
struct FSEventWatcherTests {
  @Test("Moving a top-level folder out reports a membership event")
  func reportsTopLevelFolderRemoval() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let watched = root.appendingPathComponent(
      "FolderHubLibrary",
      isDirectory: true
    )
    let folder = watched.appendingPathComponent(
      "Projects",
      isDirectory: true
    )
    let moved = root.appendingPathComponent("Projects", isDirectory: true)
    try FileManager.default.createDirectory(
      at: folder,
      withIntermediateDirectories: true
    )

    let expectation = XCTestExpectation(
      description: "FSEvents reports the moved folder"
    )
    let reconciler = ManagedLibraryReconciler(rootURL: watched)
    let watcher = FSEventWatcher()
    watcher.start(
      watching: watched,
      onEvents: { eventPaths in
        if reconciler.affectsMembership(eventPaths: eventPaths) {
          expectation.fulfill()
        }
      }
    )
    defer { watcher.stop() }

    Thread.sleep(forTimeInterval: 0.75)
    try FileManager.default.moveItem(at: folder, to: moved)

    let result = XCTWaiter.wait(for: [expectation], timeout: 5)
    #expect(result == .completed)
  }
}

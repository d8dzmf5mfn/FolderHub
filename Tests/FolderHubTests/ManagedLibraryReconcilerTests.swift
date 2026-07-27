import Foundation
import Testing

@testable import FolderHub

@Suite("Managed library reconciliation")
struct ManagedLibraryReconcilerTests {
  @Test("Folders moved out of the managed library are removed")
  func removesFoldersThatLeftTheLibrary() {
    let root = URL(fileURLWithPath: "/tmp/FolderHubLibrary")
    let managed = record(
      name: "Managed",
      path: root.appendingPathComponent("Managed").path,
      resourceIdentifier: "managed"
    )
    let legacy = record(
      name: "Legacy",
      path: "/tmp/Legacy",
      resourceIdentifier: "legacy"
    )

    let result = ManagedLibraryReconciler(rootURL: root).reconcile(
      existing: [managed, legacy],
      discovered: [],
      maximumCount: 12
    )

    #expect(result.folders == [legacy])
    #expect(result.removedIDs == [managed.id])
    #expect(result.addedCount == 0)
  }

  @Test("Renames inside the library preserve identity and layout")
  func refreshesRenamedFolders() {
    let root = URL(fileURLWithPath: "/tmp/FolderHubLibrary")
    let id = UUID()
    let existing = record(
      id: id,
      name: "Before",
      path: root.appendingPathComponent("Before").path,
      resourceIdentifier: "same-resource",
      layoutSeed: 42
    )
    let discovered = record(
      name: "After",
      path: root.appendingPathComponent("After").path,
      resourceIdentifier: "same-resource",
      layoutSeed: 99
    )

    let result = ManagedLibraryReconciler(rootURL: root).reconcile(
      existing: [existing],
      discovered: [discovered],
      maximumCount: 12
    )

    #expect(result.folders.count == 1)
    #expect(result.folders[0].id == id)
    #expect(result.folders[0].displayName == "After")
    #expect(result.folders[0].lastKnownPath == discovered.lastKnownPath)
    #expect(result.folders[0].layoutSeed == 42)
    #expect(result.removedIDs.isEmpty)
    #expect(result.addedCount == 0)
  }

  @Test("New library folders fill only available Hub slots")
  func addsDiscoveredFoldersUpToCapacity() {
    let root = URL(fileURLWithPath: "/tmp/FolderHubLibrary")
    let existing = record(
      name: "Existing",
      path: root.appendingPathComponent("Existing").path,
      resourceIdentifier: "existing"
    )
    let first = record(
      name: "First",
      path: root.appendingPathComponent("First").path,
      resourceIdentifier: "first"
    )
    let second = record(
      name: "Second",
      path: root.appendingPathComponent("Second").path,
      resourceIdentifier: "second"
    )

    let result = ManagedLibraryReconciler(rootURL: root).reconcile(
      existing: [existing],
      discovered: [existing, first, second],
      maximumCount: 2
    )

    #expect(result.folders == [existing, first])
    #expect(result.addedCount == 1)
    #expect(result.removedIDs.isEmpty)
  }

  @Test("Only root membership events trigger reconciliation")
  func filtersNestedFileEvents() {
    let root = URL(fileURLWithPath: "/tmp/FolderHubLibrary")
    let reconciler = ManagedLibraryReconciler(rootURL: root)

    #expect(reconciler.affectsMembership(eventPaths: [root.path]))
    #expect(
      reconciler.affectsMembership(
        eventPaths: [root.appendingPathComponent("Projects").path]
      )
    )
    #expect(
      !reconciler.affectsMembership(
        eventPaths: [
          root
            .appendingPathComponent("Projects")
            .appendingPathComponent("README.md")
            .path
        ]
      )
    )
  }

  private func record(
    id: UUID = UUID(),
    name: String,
    path: String,
    resourceIdentifier: String,
    layoutSeed: UInt64 = 1
  ) -> ManagedFolderRecord {
    ManagedFolderRecord(
      id: id,
      displayName: name,
      bookmarkData: Data(name.utf8),
      bookmarkIsSecurityScoped: false,
      resourceIdentifier: resourceIdentifier,
      lastKnownPath: path,
      layoutSeed: layoutSeed
    )
  }
}

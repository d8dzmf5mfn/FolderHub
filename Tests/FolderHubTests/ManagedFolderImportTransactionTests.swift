import Foundation
import Testing

@testable import FolderHub

@Suite("Managed folder import transaction")
struct ManagedFolderImportTransactionTests {
  @Test("Successful import moves, registers, and persists the folder")
  func successfulImport() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source =
      root
      .appendingPathComponent("Desktop")
      .appendingPathComponent("Projects")
    let library = root.appendingPathComponent("FolderHubLibrary")
    let stateURL =
      root
      .appendingPathComponent("ApplicationSupport")
      .appendingPathComponent("state.json")
    try FileManager.default.createDirectory(
      at: source,
      withIntermediateDirectories: true
    )
    let persistence = HubPersistence(stateURL: stateURL)
    let transaction = ManagedFolderImportTransaction(
      bookmarkStore: BookmarkStore(),
      managedLibrary: ManagedLibraryService(rootURL: library),
      persistence: persistence
    )

    let record = try await transaction.importFolder(
      source,
      existingFolders: [],
      panelLocation: nil
    )

    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(FileManager.default.fileExists(atPath: record.lastKnownPath))
    #expect(persistence.load().folders == [record])
  }

  @Test("Persistence failure restores the folder to its source")
  func persistenceFailureRollsBackMove() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source =
      root
      .appendingPathComponent("Desktop")
      .appendingPathComponent("Projects")
    let library = root.appendingPathComponent("FolderHubLibrary")
    let blockedParent = root.appendingPathComponent("blocked")
    try FileManager.default.createDirectory(
      at: source,
      withIntermediateDirectories: true
    )
    try Data("file-blocks-directory".utf8).write(to: blockedParent)
    let transaction = ManagedFolderImportTransaction(
      bookmarkStore: BookmarkStore(),
      managedLibrary: ManagedLibraryService(rootURL: library),
      persistence: HubPersistence(
        stateURL: blockedParent.appendingPathComponent("state.json")
      )
    )

    await #expect(throws: (any Error).self) {
      _ = try await transaction.importFolder(
        source,
        existingFolders: [],
        panelLocation: nil
      )
    }

    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(
      !FileManager.default.fileExists(
        atPath: library.appendingPathComponent("Projects").path
      )
    )
  }
}

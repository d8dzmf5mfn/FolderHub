import Foundation
import Testing

@testable import FolderHub

@Suite("Managed folder library")
struct ManagedLibraryServiceTests {
  @Test("Import removes the source and restore moves it back")
  func importAndRestore() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("Source")
    let library = root.appendingPathComponent("FolderHubLibrary")
    let desktop = root.appendingPathComponent("Desktop")
    let source = sourceRoot.appendingPathComponent("Projects")
    try FileManager.default.createDirectory(
      at: source,
      withIntermediateDirectories: true
    )
    try Data("content".utf8).write(
      to: source.appendingPathComponent("README.md")
    )
    let service = ManagedLibraryService(
      rootURL: library,
      desktopURL: desktop
    )

    let imported = try await service.importFolder(source)

    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(
      imported.deletingLastPathComponent().standardizedFileURL
        == library.standardizedFileURL
    )
    #expect(
      FileManager.default.fileExists(
        atPath: imported.appendingPathComponent("README.md").path
      )
    )

    let restored = try await service.moveToDesktop(imported)

    #expect(
      restored.deletingLastPathComponent().standardizedFileURL
        == desktop.standardizedFileURL
    )
    #expect(!FileManager.default.fileExists(atPath: imported.path))
    #expect(FileManager.default.fileExists(atPath: restored.path))
  }

  @Test("Name conflicts use no-space copy suffixes")
  func conflictSuffix() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("Source")
    let library = root.appendingPathComponent("FolderHubLibrary")
    let first = sourceRoot.appendingPathComponent("Projects")
    let secondRoot = root.appendingPathComponent("AnotherSource")
    let second = secondRoot.appendingPathComponent("Projects")
    try FileManager.default.createDirectory(
      at: first,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: second,
      withIntermediateDirectories: true
    )
    let service = ManagedLibraryService(rootURL: library)

    _ = try await service.importFolder(first)
    let duplicate = try await service.importFolder(second)

    #expect(duplicate.lastPathComponent == "Projects-copy")
    #expect(!duplicate.lastPathComponent.contains(" "))
  }

  @Test("Files move into Inbox and disappear from their source")
  func importFileToInbox() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("Desktop")
    let source = sourceRoot.appendingPathComponent("Notes.md")
    let library = root.appendingPathComponent("FolderHubLibrary")
    try FileManager.default.createDirectory(
      at: sourceRoot,
      withIntermediateDirectories: true
    )
    try Data("inbox-content".utf8).write(to: source)
    let service = ManagedLibraryService(rootURL: library)

    let imported = try await service.importFileToInbox(source)

    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(imported.lastPathComponent == "Notes.md")
    #expect(
      imported.deletingLastPathComponent().standardizedFileURL
        == service.inboxURL.standardizedFileURL
    )
    #expect(
      try String(contentsOf: imported, encoding: .utf8)
        == "inbox-content"
    )
  }

  @Test("Inbox file conflicts preserve extensions without spaces")
  func inboxConflictSuffix() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let firstDesktop = root.appendingPathComponent("DesktopOne")
    let secondDesktop = root.appendingPathComponent("DesktopTwo")
    let first = firstDesktop.appendingPathComponent("Report.pdf")
    let second = secondDesktop.appendingPathComponent("Report.pdf")
    let library = root.appendingPathComponent("FolderHubLibrary")
    try FileManager.default.createDirectory(
      at: firstDesktop,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: secondDesktop,
      withIntermediateDirectories: true
    )
    try Data("first".utf8).write(to: first)
    try Data("second".utf8).write(to: second)
    let service = ManagedLibraryService(rootURL: library)

    _ = try await service.importFileToInbox(first)
    let duplicate = try await service.importFileToInbox(second)

    #expect(duplicate.lastPathComponent == "Report-copy.pdf")
    #expect(!duplicate.lastPathComponent.contains(" "))
  }

  @Test("Managed folder discovery returns only visible directories")
  func managedFolderDiscovery() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = root.appendingPathComponent("FolderHubLibrary")
    try FileManager.default.createDirectory(
      at: library.appendingPathComponent("Zulu"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: library.appendingPathComponent("Alpha"),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: library.appendingPathComponent(".hidden"),
      withIntermediateDirectories: true
    )
    try Data("not-a-folder".utf8).write(
      to: library.appendingPathComponent("Notes.md")
    )
    let service = ManagedLibraryService(rootURL: library)

    let discovered = try await service.managedFolderURLs()

    #expect(discovered.map(\.lastPathComponent) == ["Alpha", "Zulu"])
  }

  @Test("Failed registration can restore an imported folder")
  func restoreImportedFolder() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source =
      root
      .appendingPathComponent("Desktop")
      .appendingPathComponent("Projects")
    let library = root.appendingPathComponent("FolderHubLibrary")
    try FileManager.default.createDirectory(
      at: source,
      withIntermediateDirectories: true
    )
    let service = ManagedLibraryService(rootURL: library)
    let imported = try await service.importFolder(source)

    let restored = try await service.restoreImportedFolder(
      imported,
      to: source
    )

    #expect(restored.standardizedFileURL == source.standardizedFileURL)
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: imported.path))
  }
}

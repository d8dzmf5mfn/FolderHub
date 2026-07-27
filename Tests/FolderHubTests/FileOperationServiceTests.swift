import Foundation
import Testing

@testable import FolderHub

@Suite("File operations")
struct FileOperationServiceTests {
  @Test("Create, rename, and keep-both move preserve data")
  func createRenameAndMove() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceDirectory = root.appendingPathComponent("Source")
    let destinationDirectory = root.appendingPathComponent("Destination")
    try FileManager.default.createDirectory(
      at: sourceDirectory,
      withIntermediateDirectories: false
    )
    try FileManager.default.createDirectory(
      at: destinationDirectory,
      withIntermediateDirectories: false
    )

    let service = FileOperationService()
    let created = try await service.createFolder(
      named: "NewFolder",
      in: sourceDirectory
    )
    let renamed = try await service.rename(
      makeDirectoryItem(at: created, isDirectory: true),
      to: "Renamed"
    )
    #expect(FileManager.default.fileExists(atPath: renamed.path))

    let originalFile = sourceDirectory.appendingPathComponent("Note.md")
    let existingFile = destinationDirectory.appendingPathComponent("Note.md")
    try Data("original".utf8).write(to: originalFile)
    try Data("existing".utf8).write(to: existingFile)

    let moved = try await service.move(
      originalFile,
      to: destinationDirectory,
      conflictResolution: .keepBoth
    )

    #expect(moved?.lastPathComponent == "Note-copy.md")
    #expect(try String(contentsOf: moved!, encoding: .utf8) == "original")
    #expect(try String(contentsOf: existingFile, encoding: .utf8) == "existing")
  }

  @Test("Moving a folder into itself is rejected")
  func rejectsRecursiveMove() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let child = root.appendingPathComponent("Child")
    try FileManager.default.createDirectory(
      at: child,
      withIntermediateDirectories: false
    )

    let service = FileOperationService()
    await #expect(throws: FileOperationError.self) {
      _ = try await service.move(
        root,
        to: child,
        conflictResolution: .cancel
      )
    }
  }
}

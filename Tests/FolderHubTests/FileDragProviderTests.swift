import Foundation
import Testing
import UniformTypeIdentifiers

@testable import FolderHub

@Suite("File drag provider")
struct FileDragProviderTests {
  @Test("Exports a file URL with its original name")
  func exportsFileURL() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("ReleaseNotes.md")
    try Data("content".utf8).write(to: source)

    let provider = FileDragProvider.make(for: source)

    #expect(provider.suggestedName == "ReleaseNotes.md")
    #expect(
      provider.hasItemConformingToTypeIdentifier(
        UTType.fileURL.identifier
      )
    )
  }
}

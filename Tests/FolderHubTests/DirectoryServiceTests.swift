import Foundation
import Testing

@testable import FolderHub

@Suite("Directory contents")
struct DirectoryServiceTests {
  @Test("Folders sort before files and hidden items are optional")
  func sortingAndHiddenFiles() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Beta"),
      withIntermediateDirectories: false
    )
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Alpha"),
      withIntermediateDirectories: false
    )
    try Data("z".utf8).write(to: root.appendingPathComponent("Zulu.md"))
    try Data("a".utf8).write(to: root.appendingPathComponent("Alpha.md"))
    try Data("h".utf8).write(to: root.appendingPathComponent(".Hidden"))

    let service = DirectoryService()
    let visible = try service.contents(of: root, showHiddenFiles: false)
    let all = try service.contents(of: root, showHiddenFiles: true)

    #expect(visible.map(\.name) == ["Alpha", "Beta", "Alpha.md", "Zulu.md"])
    #expect(visible.allSatisfy { !$0.isHidden })
    #expect(all.contains { $0.name == ".Hidden" && $0.isHidden })
  }
}

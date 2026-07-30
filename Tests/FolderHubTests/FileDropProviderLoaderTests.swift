import Foundation
import Testing
import UniformTypeIdentifiers

@testable import FolderHub

@Suite("File drop provider loading")
struct FileDropProviderLoaderTests {
  @Test("Loads every dropped URL once and preserves provider order")
  func loadsBatchInOrder() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appendingPathComponent("First.txt")
    let second = root.appendingPathComponent("Second")
    try Data("first".utf8).write(to: first)
    try FileManager.default.createDirectory(
      at: second,
      withIntermediateDirectories: true
    )
    let firstProvider = try #require(NSItemProvider(contentsOf: first))
    let secondProvider = try #require(NSItemProvider(contentsOf: second))
    let duplicateProvider = try #require(NSItemProvider(contentsOf: first))

    let result = await load([
      firstProvider,
      secondProvider,
      duplicateProvider,
    ])

    #expect(
      result.urls.map(\.path) == [
        first.standardizedFileURL.path,
        second.standardizedFileURL.path,
      ]
    )
    #expect(result.unreadableItemCount == 0)
  }

  @Test("Reports unreadable providers without dropping valid URLs")
  func reportsPartialFailure() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let validURL = root.appendingPathComponent("Valid.txt")
    try Data("valid".utf8).write(to: validURL)

    let invalidProvider = NSItemProvider()
    invalidProvider.registerDataRepresentation(
      forTypeIdentifier: UTType.fileURL.identifier,
      visibility: .all
    ) { completion in
      completion(Data([0xFF, 0x00]), nil)
      return nil
    }

    let result = await load([
      FileDragProvider.make(for: validURL),
      invalidProvider,
    ])

    #expect(result.urls == [validURL.standardizedFileURL])
    #expect(result.unreadableItemCount == 1)
  }

  @Test("Decodes URL, data, and absolute path payloads")
  func decodesSupportedPayloads() {
    let url = URL(fileURLWithPath: "/tmp/Folder Hub/Test.txt")

    #expect(FileDropProviderLoader.fileURL(from: url) == url)
    #expect(
      FileDropProviderLoader.fileURL(from: url.dataRepresentation) == url
    )
    #expect(FileDropProviderLoader.fileURL(from: url.absoluteString) == url)
    #expect(FileDropProviderLoader.fileURL(from: url.path) == url)
    #expect(FileDropProviderLoader.fileURL(from: "https://example.com") == nil)
  }

  @Test("Rejects providers without file URLs")
  func rejectsNonFileProviders() {
    let accepted = FileDropProviderLoader.loadURLs(
      from: [NSItemProvider()]
    ) { _ in
      Issue.record("Completion must not run for an unsupported drop")
    }

    #expect(!accepted)
  }

  private func load(_ providers: [NSItemProvider]) async -> FileDropLoadResult {
    await withCheckedContinuation { continuation in
      let accepted = FileDropProviderLoader.loadURLs(from: providers) {
        continuation.resume(returning: $0)
      }
      #expect(accepted)
    }
  }
}

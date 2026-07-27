import Foundation
import Testing

@testable import FolderHub

@Suite("Hub persistence")
struct HubPersistenceTests {
  @Test("State round-trips through an atomic save")
  func roundTrip() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appendingPathComponent("state.json")
    let persistence = HubPersistence(stateURL: stateURL)
    let folder = makeFolderRecord(name: "Projects", seed: 42)
    let expected = PersistedHubState(
      folders: [folder],
      panelLocation: SavedPanelLocation(
        displayIdentifier: "display",
        normalizedX: 0.4,
        normalizedY: 0.7
      )
    )

    try persistence.save(expected)
    let loaded = persistence.load()

    #expect(loaded.version == PersistedHubState.currentVersion)
    #expect(loaded.folders == expected.folders)
    #expect(loaded.panelLocation == expected.panelLocation)
    #expect(FileManager.default.fileExists(atPath: stateURL.path))
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: root.path)
        == ["state.json"]
    )
  }

  @Test("Invalid state safely returns an empty model")
  func invalidStateFallback() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let stateURL = root.appendingPathComponent("state.json")
    try Data("not-json".utf8).write(to: stateURL)

    let loaded = HubPersistence(stateURL: stateURL).load()

    #expect(loaded.folders.isEmpty)
    #expect(loaded.panelLocation == nil)
  }
}

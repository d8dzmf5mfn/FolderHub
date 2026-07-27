import Foundation

struct HubPersistence {
  private let fileManager: FileManager
  private let stateURL: URL

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
    let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    stateURL =
      applicationSupport
      .appendingPathComponent("FolderHub", isDirectory: true)
      .appendingPathComponent("state.json", isDirectory: false)
  }

  init(fileManager: FileManager = .default, stateURL: URL) {
    self.fileManager = fileManager
    self.stateURL = stateURL
  }

  func load() -> PersistedHubState {
    guard let data = try? Data(contentsOf: stateURL),
      let state = try? JSONDecoder().decode(PersistedHubState.self, from: data),
      state.version == PersistedHubState.currentVersion
    else {
      return PersistedHubState(folders: [], panelLocation: nil)
    }
    return state
  }

  func save(_ state: PersistedHubState) throws {
    let directory = stateURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    let temporaryURL = directory.appendingPathComponent(
      ".state-\(UUID().uuidString).partial"
    )

    do {
      try data.write(to: temporaryURL)
      let handle = try FileHandle(forWritingTo: temporaryURL)
      try handle.synchronize()
      try handle.close()

      if fileManager.fileExists(atPath: stateURL.path) {
        _ = try fileManager.replaceItemAt(
          stateURL,
          withItemAt: temporaryURL
        )
      } else {
        try fileManager.moveItem(at: temporaryURL, to: stateURL)
      }
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw error
    }
  }
}

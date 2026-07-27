import Foundation

struct ManagedFolderRecord: Codable, Identifiable, Hashable, Sendable {
  let id: UUID
  var displayName: String
  var bookmarkData: Data
  var bookmarkIsSecurityScoped: Bool
  var resourceIdentifier: String
  var lastKnownPath: String
  var layoutSeed: UInt64

  init(
    id: UUID = UUID(),
    displayName: String,
    bookmarkData: Data,
    bookmarkIsSecurityScoped: Bool,
    resourceIdentifier: String,
    lastKnownPath: String,
    layoutSeed: UInt64? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.bookmarkData = bookmarkData
    self.bookmarkIsSecurityScoped = bookmarkIsSecurityScoped
    self.resourceIdentifier = resourceIdentifier
    self.lastKnownPath = lastKnownPath
    self.layoutSeed = layoutSeed ?? Self.seed(for: id)
  }

  static func seed(for id: UUID) -> UInt64 {
    id.uuidString.utf8.reduce(1_469_598_103_934_665_603) {
      ($0 ^ UInt64($1)) &* 1_099_511_628_211
    }
  }
}

struct SavedPanelLocation: Codable, Equatable, Sendable {
  var displayIdentifier: String
  var normalizedX: Double
  var normalizedY: Double
}

struct PersistedHubState: Codable, Sendable {
  static let currentVersion = 1

  var version: Int = currentVersion
  var folders: [ManagedFolderRecord]
  var panelLocation: SavedPanelLocation?
}

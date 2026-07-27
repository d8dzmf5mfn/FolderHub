import Foundation

struct DirectoryItem: Identifiable, Hashable, Sendable {
  let url: URL
  let name: String
  let isDirectory: Bool
  let isPackage: Bool
  let isSymbolicLink: Bool
  let isHidden: Bool
  let modifiedAt: Date?

  var id: URL { url }

  var isNavigableDirectory: Bool {
    isDirectory && !isPackage && !isSymbolicLink
  }
}

struct TrashedItem: Sendable {
  let originalURL: URL
  let trashURL: URL
}

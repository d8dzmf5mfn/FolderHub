import Foundation

@testable import FolderHub

func makeTemporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("FolderHubTests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(
    at: url,
    withIntermediateDirectories: true
  )
  return url
}

func makeFolderRecord(
  name: String,
  id: UUID = UUID(),
  seed: UInt64
) -> ManagedFolderRecord {
  ManagedFolderRecord(
    id: id,
    displayName: name,
    bookmarkData: Data(),
    bookmarkIsSecurityScoped: false,
    resourceIdentifier: id.uuidString,
    lastKnownPath: "/tmp/\(name)",
    layoutSeed: seed
  )
}

func makeDirectoryItem(at url: URL, isDirectory: Bool = false) -> DirectoryItem {
  DirectoryItem(
    url: url,
    name: url.lastPathComponent,
    isDirectory: isDirectory,
    isPackage: false,
    isSymbolicLink: false,
    isHidden: false,
    modifiedAt: nil
  )
}

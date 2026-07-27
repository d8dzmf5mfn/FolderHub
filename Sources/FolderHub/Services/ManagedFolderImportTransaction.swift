import Foundation

enum ManagedFolderImportTransactionError: LocalizedError {
  case rollbackFailed(managedPath: String)

  var errorDescription: String? {
    switch self {
    case .rollbackFailed(let managedPath):
      "The folder moved, but Folder Hub could not register or restore it. "
        + "It remains at \(managedPath)."
    }
  }
}

struct ManagedFolderImportTransaction {
  let bookmarkStore: BookmarkStore
  let managedLibrary: ManagedLibraryService
  let persistence: HubPersistence

  func importFolder(
    _ rawURL: URL,
    existingFolders: [ManagedFolderRecord],
    panelLocation: SavedPanelLocation?
  ) async throws -> ManagedFolderRecord {
    let sourceURL = rawURL.standardizedFileURL
    let managedURL = try await managedLibrary.importFolder(sourceURL)

    do {
      let record = try bookmarkStore.makeRecord(for: managedURL)
      try persistence.save(
        PersistedHubState(
          folders: existingFolders + [record],
          panelLocation: panelLocation
        )
      )
      return record
    } catch {
      let importError = error
      guard managedURL != sourceURL else {
        throw importError
      }
      do {
        _ = try await managedLibrary.restoreImportedFolder(
          managedURL,
          to: sourceURL
        )
      } catch {
        throw ManagedFolderImportTransactionError.rollbackFailed(
          managedPath: managedURL.path
        )
      }
      throw importError
    }
  }
}

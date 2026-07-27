import Foundation

struct ResolvedBookmark: Sendable {
  let url: URL
  let isStale: Bool
  let didStartSecurityScope: Bool
}

enum BookmarkStoreError: LocalizedError {
  case notDirectory
  case inaccessible

  var errorDescription: String? {
    switch self {
    case .notDirectory:
      "Folder Hub only accepts folders."
    case .inaccessible:
      "The folder can no longer be accessed. Add it again to reauthorize."
    }
  }
}

struct BookmarkStore: Sendable {
  func makeRecord(for rawURL: URL) throws -> ManagedFolderRecord {
    let url = rawURL.standardizedFileURL
    let values = try url.resourceValues(
      forKeys: [.nameKey, .isDirectoryKey, .fileResourceIdentifierKey]
    )
    guard values.isDirectory == true else {
      throw BookmarkStoreError.notDirectory
    }

    let bookmark: Data
    let isSecurityScoped: Bool
    do {
      bookmark = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: [
          .nameKey,
          .isDirectoryKey,
          .fileResourceIdentifierKey,
        ],
        relativeTo: nil
      )
      isSecurityScoped = true
    } catch {
      bookmark = try url.bookmarkData(
        options: [],
        includingResourceValuesForKeys: [
          .nameKey,
          .isDirectoryKey,
          .fileResourceIdentifierKey,
        ],
        relativeTo: nil
      )
      isSecurityScoped = false
    }

    return ManagedFolderRecord(
      displayName: values.name ?? url.lastPathComponent,
      bookmarkData: bookmark,
      bookmarkIsSecurityScoped: isSecurityScoped,
      resourceIdentifier: Self.resourceIdentifier(
        values.fileResourceIdentifier,
        fallbackURL: url
      ),
      lastKnownPath: url.path
    )
  }

  func resolve(_ record: ManagedFolderRecord) throws -> ResolvedBookmark {
    var isStale = false
    let options: URL.BookmarkResolutionOptions =
      record.bookmarkIsSecurityScoped ? [.withSecurityScope] : []
    let url = try URL(
      resolvingBookmarkData: record.bookmarkData,
      options: options,
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    ).standardizedFileURL

    guard FileManager.default.fileExists(atPath: url.path) else {
      throw BookmarkStoreError.inaccessible
    }

    let didStart =
      record.bookmarkIsSecurityScoped
      ? url.startAccessingSecurityScopedResource()
      : false
    return ResolvedBookmark(
      url: url,
      isStale: isStale,
      didStartSecurityScope: didStart
    )
  }

  func refresh(_ record: ManagedFolderRecord, resolvedURL: URL) throws
    -> ManagedFolderRecord
  {
    var refreshed = try makeRecord(for: resolvedURL)
    refreshed = ManagedFolderRecord(
      id: record.id,
      displayName: refreshed.displayName,
      bookmarkData: refreshed.bookmarkData,
      bookmarkIsSecurityScoped: refreshed.bookmarkIsSecurityScoped,
      resourceIdentifier: refreshed.resourceIdentifier,
      lastKnownPath: refreshed.lastKnownPath,
      layoutSeed: record.layoutSeed
    )
    return refreshed
  }

  static func resourceIdentifier(
    _ value: (any NSCopying & NSSecureCoding & NSObjectProtocol)?,
    fallbackURL: URL
  ) -> String {
    if let value {
      return String(describing: value)
    }
    return fallbackURL.resolvingSymlinksInPath().path
  }
}

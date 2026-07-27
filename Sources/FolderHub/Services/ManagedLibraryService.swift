import Foundation

enum ManagedLibraryError: LocalizedError {
  case cannotImportLibrary
  case notDirectory
  case notFile

  var errorDescription: String? {
    switch self {
    case .cannotImportLibrary:
      "Add folders inside FolderHubLibrary, not the library itself."
    case .notDirectory:
      "Folder Hub only accepts folders."
    case .notFile:
      "Inbox only accepts files."
    }
  }
}

actor ManagedLibraryService {
  nonisolated let rootURL: URL
  nonisolated var inboxURL: URL {
    rootURL.appendingPathComponent("Inbox", isDirectory: true)
  }
  private let fileManager: FileManager
  private let desktopURL: URL?

  init(
    rootURL: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("FolderHubLibrary", isDirectory: true),
    desktopURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.rootURL = rootURL.standardizedFileURL
    self.desktopURL = desktopURL?.standardizedFileURL
    self.fileManager = fileManager
  }

  func importFolder(_ rawURL: URL) throws -> URL {
    let source = rawURL.standardizedFileURL
    var isDirectory: ObjCBool = false
    guard
      fileManager.fileExists(
        atPath: source.path,
        isDirectory: &isDirectory
      ),
      isDirectory.boolValue
    else {
      throw ManagedLibraryError.notDirectory
    }
    guard source != rootURL else {
      throw ManagedLibraryError.cannotImportLibrary
    }

    try ensureLibraryExists()
    guard source.deletingLastPathComponent() != rootURL else {
      return source
    }

    var destination = rootURL.appendingPathComponent(
      source.lastPathComponent,
      isDirectory: true
    )
    if fileManager.fileExists(atPath: destination.path) {
      destination = uniqueURL(for: destination, isDirectory: true)
    }
    try fileManager.moveItem(at: source, to: destination)
    return destination
  }

  func restoreImportedFolder(
    _ rawManagedURL: URL,
    to rawOriginalURL: URL
  ) throws -> URL {
    let managedURL = rawManagedURL.standardizedFileURL
    let originalURL = rawOriginalURL.standardizedFileURL
    guard managedURL != originalURL else {
      return originalURL
    }

    let originalDirectory = originalURL.deletingLastPathComponent()
    try fileManager.createDirectory(
      at: originalDirectory,
      withIntermediateDirectories: true
    )

    var destination = originalURL
    if fileManager.fileExists(atPath: destination.path) {
      destination = uniqueURL(for: destination, isDirectory: true)
    }
    try fileManager.moveItem(at: managedURL, to: destination)
    return destination
  }

  func managedFolderURLs() throws -> [URL] {
    try ensureLibraryExists()
    let urls = try fileManager.contentsOfDirectory(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    return
      try urls
      .filter {
        try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
      }
      .sorted {
        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
          == .orderedAscending
      }
  }

  func importFileToInbox(_ rawURL: URL) throws -> URL {
    let source = rawURL.standardizedFileURL
    var isDirectory: ObjCBool = false
    guard
      fileManager.fileExists(
        atPath: source.path,
        isDirectory: &isDirectory
      ),
      !isDirectory.boolValue
    else {
      throw ManagedLibraryError.notFile
    }

    try ensureInboxExists()
    if source.deletingLastPathComponent().standardizedFileURL
      == inboxURL.standardizedFileURL
    {
      return source
    }

    var destination = inboxURL.appendingPathComponent(
      source.lastPathComponent,
      isDirectory: false
    )
    if fileManager.fileExists(atPath: destination.path) {
      destination = uniqueURL(for: destination, isDirectory: false)
    }
    try fileManager.moveItem(at: source, to: destination)
    return destination
  }

  func moveToDesktop(_ rawURL: URL) throws -> URL {
    let source = rawURL.standardizedFileURL
    let desktop =
      if let desktopURL {
        desktopURL
      } else {
        try fileManager.url(
          for: .desktopDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
      }
    try fileManager.createDirectory(
      at: desktop,
      withIntermediateDirectories: true
    )
    var destination = desktop.appendingPathComponent(
      source.lastPathComponent,
      isDirectory: true
    )
    if fileManager.fileExists(atPath: destination.path) {
      destination = uniqueURL(for: destination, isDirectory: true)
    }
    try fileManager.moveItem(at: source, to: destination)
    return destination
  }

  func ensureLibraryExists() throws {
    try fileManager.createDirectory(
      at: rootURL,
      withIntermediateDirectories: true
    )
  }

  func ensureInboxExists() throws {
    try ensureLibraryExists()
    try fileManager.createDirectory(
      at: inboxURL,
      withIntermediateDirectories: true
    )
  }

  private func uniqueURL(
    for original: URL,
    isDirectory: Bool
  ) -> URL {
    let directory = original.deletingLastPathComponent()
    let extensionName = isDirectory ? "" : original.pathExtension
    let baseName =
      extensionName.isEmpty
      ? original.lastPathComponent
      : original.deletingPathExtension().lastPathComponent
    var index = 1

    while true {
      let suffix = index == 1 ? "-copy" : "-copy-\(index)"
      var candidate = directory.appendingPathComponent(
        baseName + suffix,
        isDirectory: isDirectory
      )
      if !extensionName.isEmpty {
        candidate.appendPathExtension(extensionName)
      }
      if !fileManager.fileExists(atPath: candidate.path) {
        return candidate
      }
      index += 1
    }
  }
}

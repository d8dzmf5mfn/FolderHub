import Foundation

enum FileConflictResolution: Sendable {
  case cancel
  case replace
  case keepBoth
}

enum FileOperationError: LocalizedError {
  case invalidName
  case destinationExists(URL)
  case destinationInsideSource
  case restoreConflict

  var errorDescription: String? {
    switch self {
    case .invalidName:
      "Names can’t be empty or contain a slash."
    case .destinationExists(let url):
      "An item named “\(url.lastPathComponent)” already exists."
    case .destinationInsideSource:
      "A folder can’t be moved inside itself."
    case .restoreConflict:
      "The original location now contains another item with the same name."
    }
  }
}

actor FileOperationService {
  private let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func rename(_ item: DirectoryItem, to proposedName: String) throws -> URL {
    let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !name.contains("/") else {
      throw FileOperationError.invalidName
    }
    let destination = item.url.deletingLastPathComponent()
      .appendingPathComponent(name)
    guard destination != item.url else { return item.url }
    guard !fileManager.fileExists(atPath: destination.path) else {
      throw FileOperationError.destinationExists(destination)
    }
    try fileManager.moveItem(at: item.url, to: destination)
    return destination
  }

  func createFolder(named proposedName: String, in directory: URL) throws -> URL {
    let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !name.contains("/") else {
      throw FileOperationError.invalidName
    }
    let destination = directory.appendingPathComponent(name, isDirectory: true)
    guard !fileManager.fileExists(atPath: destination.path) else {
      throw FileOperationError.destinationExists(destination)
    }
    try fileManager.createDirectory(
      at: destination,
      withIntermediateDirectories: false
    )
    return destination
  }

  func move(
    _ source: URL,
    to destinationDirectory: URL,
    conflictResolution: FileConflictResolution
  ) throws -> URL? {
    let standardizedSource = source.standardizedFileURL
    let standardizedDirectory = destinationDirectory.standardizedFileURL
    if standardizedDirectory.path.hasPrefix(standardizedSource.path + "/") {
      throw FileOperationError.destinationInsideSource
    }

    var destination = standardizedDirectory.appendingPathComponent(
      standardizedSource.lastPathComponent,
      isDirectory: standardizedSource.hasDirectoryPath
    )
    if fileManager.fileExists(atPath: destination.path) {
      switch conflictResolution {
      case .cancel:
        return nil
      case .replace:
        var trashedURL: NSURL?
        try fileManager.trashItem(
          at: destination,
          resultingItemURL: &trashedURL
        )
      case .keepBoth:
        destination = uniqueCopyURL(for: destination)
      }
    }
    try fileManager.moveItem(at: standardizedSource, to: destination)
    return destination
  }

  func trash(_ item: DirectoryItem) throws -> TrashedItem {
    var resultingURL: NSURL?
    try fileManager.trashItem(
      at: item.url,
      resultingItemURL: &resultingURL
    )
    guard let trashURL = resultingURL as URL? else {
      throw CocoaError(.fileWriteUnknown)
    }
    return TrashedItem(originalURL: item.url, trashURL: trashURL)
  }

  func restore(_ item: TrashedItem) throws {
    guard !fileManager.fileExists(atPath: item.originalURL.path) else {
      throw FileOperationError.restoreConflict
    }
    try fileManager.moveItem(at: item.trashURL, to: item.originalURL)
  }

  private func uniqueCopyURL(for original: URL) -> URL {
    let directory = original.deletingLastPathComponent()
    let extensionName = original.pathExtension
    let baseName = original.deletingPathExtension().lastPathComponent
    var index = 1

    while true {
      let suffix = index == 1 ? "-copy" : "-copy-\(index)"
      var candidate = directory.appendingPathComponent(baseName + suffix)
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

import Foundation

struct DirectoryService: Sendable {
  func contents(of directory: URL, showHiddenFiles: Bool) throws
    -> [DirectoryItem]
  {
    let keys: Set<URLResourceKey> = [
      .nameKey,
      .isDirectoryKey,
      .isPackageKey,
      .isSymbolicLinkKey,
      .isHiddenKey,
      .contentModificationDateKey,
    ]
    var options: FileManager.DirectoryEnumerationOptions = []
    if !showHiddenFiles {
      options.insert(.skipsHiddenFiles)
    }

    let urls = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: Array(keys),
      options: options
    )
    return try urls.map { url in
      let values = try url.resourceValues(forKeys: keys)
      let isDirectory = values.isDirectory == true
      let isPackage = values.isPackage == true
      let isSymbolicLink = values.isSymbolicLink == true
      let isNavigableDirectory =
        isDirectory && !isPackage && !isSymbolicLink
      return DirectoryItem(
        url: url,
        name: values.name ?? url.lastPathComponent,
        isDirectory: isDirectory,
        isPackage: isPackage,
        isSymbolicLink: isSymbolicLink,
        isHidden: values.isHidden == true,
        modifiedAt: values.contentModificationDate,
        visibleChildCount: isNavigableDirectory
          ? childCount(
            of: url,
            showHiddenFiles: showHiddenFiles
          )
          : nil
      )
    }
    .filter { showHiddenFiles || !$0.isHidden }
    .sorted { left, right in
      if left.isNavigableDirectory != right.isNavigableDirectory {
        return left.isNavigableDirectory
      }
      return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }
  }

  func childCount(
    of directory: URL,
    showHiddenFiles: Bool
  ) -> Int? {
    var options: FileManager.DirectoryEnumerationOptions = []
    if !showHiddenFiles {
      options.insert(.skipsHiddenFiles)
    }
    return autoreleasepool {
      try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: options
      ).count
    }
  }
}

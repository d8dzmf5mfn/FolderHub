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
      return DirectoryItem(
        url: url,
        name: values.name ?? url.lastPathComponent,
        isDirectory: values.isDirectory == true,
        isPackage: values.isPackage == true,
        isSymbolicLink: values.isSymbolicLink == true,
        isHidden: values.isHidden == true,
        modifiedAt: values.contentModificationDate
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
}

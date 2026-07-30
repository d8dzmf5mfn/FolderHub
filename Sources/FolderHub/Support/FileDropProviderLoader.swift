import Foundation
import UniformTypeIdentifiers

struct FileDropLoadResult: Equatable, Sendable {
  let urls: [URL]
  let unreadableItemCount: Int
}

enum FileDropProviderLoader {
  @discardableResult
  static func loadURLs(
    from providers: [NSItemProvider],
    completion: @escaping (FileDropLoadResult) -> Void
  ) -> Bool {
    let fileProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }
    guard !fileProviders.isEmpty else { return false }

    let group = DispatchGroup()
    let accumulator = FileDropLoadAccumulator(count: fileProviders.count)

    for (index, provider) in fileProviders.enumerated() {
      group.enter()
      loadURL(from: provider) { url in
        accumulator.store(url, at: index)
        group.leave()
      }
    }

    group.notify(queue: .main) {
      completion(accumulator.result())
    }
    return true
  }

  static func fileURL(from item: Any?) -> URL? {
    if let value = item as? URL {
      return normalizedFileURL(value)
    }
    if let value = item as? NSURL {
      return normalizedFileURL(value as URL)
    }
    if let value = item as? Data,
      let url = URL(dataRepresentation: value, relativeTo: nil)
    {
      return normalizedFileURL(url)
    }
    if let value = item as? String {
      return fileURL(from: value)
    }
    if let value = item as? NSString {
      return fileURL(from: value as String)
    }
    return nil
  }

  private static func loadURL(
    from provider: NSItemProvider,
    completion: @escaping (URL?) -> Void
  ) {
    provider.loadItem(
      forTypeIdentifier: UTType.fileURL.identifier,
      options: nil
    ) { item, _ in
      if let url = fileURL(from: item) {
        completion(url)
        return
      }

      provider.loadDataRepresentation(
        forTypeIdentifier: UTType.fileURL.identifier
      ) { data, _ in
        completion(data.flatMap { fileURL(from: $0) })
      }
    }
  }

  private static func fileURL(from value: String) -> URL? {
    if let url = URL(string: value), url.isFileURL {
      return normalizedFileURL(url)
    }
    guard value.hasPrefix("/") else { return nil }
    return normalizedFileURL(URL(fileURLWithPath: value))
  }

  private static func normalizedFileURL(_ url: URL) -> URL? {
    guard url.isFileURL else { return nil }
    return url.standardizedFileURL
  }
}

private final class FileDropLoadAccumulator: @unchecked Sendable {
  private let lock = NSLock()
  private var loadedURLs: [URL?]

  init(count: Int) {
    loadedURLs = Array(repeating: nil, count: count)
  }

  func store(_ url: URL?, at index: Int) {
    lock.lock()
    loadedURLs[index] = url
    lock.unlock()
  }

  func result() -> FileDropLoadResult {
    lock.lock()
    let snapshot = loadedURLs
    lock.unlock()

    var seenPaths = Set<String>()
    let uniqueURLs = snapshot.compactMap { url -> URL? in
      guard let url, seenPaths.insert(url.path).inserted else { return nil }
      return url
    }
    return FileDropLoadResult(
      urls: uniqueURLs,
      unreadableItemCount: snapshot.count - snapshot.compactMap(\.self).count
    )
  }
}

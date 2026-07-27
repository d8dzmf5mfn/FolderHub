import Foundation
import UniformTypeIdentifiers

enum FileDragProvider {
  static func make(for rawURL: URL) -> NSItemProvider {
    let url = rawURL.standardizedFileURL
    let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider()
    provider.suggestedName = url.lastPathComponent
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.fileURL.identifier,
      visibility: .all
    ) { completion in
      completion(url.dataRepresentation, nil)
      return nil
    }
    return provider
  }
}

import CoreGraphics
import Foundation

struct HubLabelLayout: Equatable, Sendable {
  let folderID: UUID
  var centerOffset: CGPoint
  let estimatedSize: CGSize
}

struct HubLayoutSnapshot: Equatable, Sendable {
  var labels: [UUID: HubLabelLayout]

  static let empty = HubLayoutSnapshot(labels: [:])
}

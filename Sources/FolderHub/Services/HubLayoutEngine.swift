import CoreGraphics
import Foundation

struct HubLayoutEngine: Sendable {
  private let slots: [CGPoint] = [
    CGPoint(x: -34, y: -6),
    CGPoint(x: 34, y: 3),
    CGPoint(x: 2, y: -33),
    CGPoint(x: 0, y: 35),
    CGPoint(x: -52, y: -38),
    CGPoint(x: 47, y: 31),
    CGPoint(x: -26, y: -63),
    CGPoint(x: 26, y: 60),
    CGPoint(x: 52, y: -40),
    CGPoint(x: -49, y: 29),
    CGPoint(x: 26, y: -61),
    CGPoint(x: -26, y: 61),
  ]

  func layout(
    folders: [ManagedFolderRecord],
    previous: HubLayoutSnapshot = .empty,
    hubDiameter: CGFloat? = nil
  ) -> HubLayoutSnapshot {
    guard !folders.isEmpty else { return .empty }

    let resolvedDiameter =
      hubDiameter
      ?? recommendedHubDiameter(folders: folders)
    let innerRadius =
      resolvedDiameter / 2 - HubSizingPolicy.contentInset
    let candidates = labelCandidates(folders: folders)
    let labels = candidates.map { candidate in
      HubLabelLayout(
        folderID: candidate.folderID,
        centerOffset: constrained(
          candidate.centerOffset,
          size: candidate.estimatedSize,
          innerRadius: innerRadius
        ),
        estimatedSize: candidate.estimatedSize
      )
    }

    return HubLayoutSnapshot(
      labels: Dictionary(
        uniqueKeysWithValues: labels.map { ($0.folderID, $0) }
      )
    )
  }

  func recommendedHubDiameter(
    folders: [ManagedFolderRecord]
  ) -> CGFloat {
    guard !folders.isEmpty else {
      return HubSizingPolicy.minimumDiameter(forFolderCount: 0)
    }

    let candidates = labelCandidates(folders: folders)
    let requiredRadius =
      candidates.flatMap { candidate in
        let halfWidth = candidate.estimatedSize.width / 2
        let halfHeight = candidate.estimatedSize.height / 2
        return [
          CGPoint(
            x: candidate.centerOffset.x - halfWidth,
            y: candidate.centerOffset.y - halfHeight
          ),
          CGPoint(
            x: candidate.centerOffset.x + halfWidth,
            y: candidate.centerOffset.y - halfHeight
          ),
          CGPoint(
            x: candidate.centerOffset.x - halfWidth,
            y: candidate.centerOffset.y + halfHeight
          ),
          CGPoint(
            x: candidate.centerOffset.x + halfWidth,
            y: candidate.centerOffset.y + halfHeight
          ),
        ]
      }
      .map { hypot($0.x, $0.y) }
      .max() ?? 0

    let contentDiameter =
      (requiredRadius + HubSizingPolicy.contentInset) * 2
    let roundedDiameter = ceil(contentDiameter / 2) * 2
    return min(
      max(
        roundedDiameter,
        HubSizingPolicy.minimumDiameter(
          forFolderCount: folders.count
        )
      ),
      HubSizingPolicy.maximumDiameter
    )
  }

  private func labelCandidates(
    folders: [ManagedFolderRecord]
  ) -> [HubLabelLayout] {
    let selectedSlots = Array(slots.prefix(folders.count))
    let centroid = selectedSlots.reduce(CGPoint.zero) { partial, point in
      CGPoint(x: partial.x + point.x, y: partial.y + point.y)
    }
    .scaled(by: 1 / CGFloat(selectedSlots.count))
    let scale: CGFloat = folders.count == 1 ? 0 : 1
    let rotation = sin(CGFloat(folders.count) * 1.7) * 0.045
    let cosine = cos(rotation)
    let sine = sin(rotation)

    let labels = zip(folders, selectedSlots).map { folder, slot in
      let centered = CGPoint(
        x: (slot.x - centroid.x) * scale,
        y: (slot.y - centroid.y) * scale
      )
      let rotated = CGPoint(
        x: centered.x * cosine - centered.y * sine,
        y: centered.x * sine + centered.y * cosine
      )
      let size = estimatedSize(
        for: folder.displayName,
        folderCount: folders.count
      )
      return HubLabelLayout(
        folderID: folder.id,
        centerOffset: rotated,
        estimatedSize: size
      )
    }
    return labels
  }

  private func estimatedSize(for name: String, folderCount: Int) -> CGSize {
    let visibleCharacters = min(max(name.count, 4), 20)
    let maximumWidth: CGFloat = folderCount <= 4 ? 64 : 44
    return CGSize(
      width: min(CGFloat(visibleCharacters) * 5.2 + 8, maximumWidth),
      height: 16
    )
  }

  private func constrained(
    _ point: CGPoint,
    size: CGSize,
    innerRadius: CGFloat
  ) -> CGPoint {
    let corners = [
      CGPoint(x: -size.width / 2, y: -size.height / 2),
      CGPoint(x: size.width / 2, y: -size.height / 2),
      CGPoint(x: -size.width / 2, y: size.height / 2),
      CGPoint(x: size.width / 2, y: size.height / 2),
    ]
    let farthestDistance =
      corners.map {
        hypot(point.x + $0.x, point.y + $0.y)
      }.max() ?? 0
    guard farthestDistance > innerRadius else {
      return point
    }

    var lowerBound: CGFloat = 0
    var upperBound: CGFloat = 1
    for _ in 0..<24 {
      let candidateScale = (lowerBound + upperBound) / 2
      let candidate = point.scaled(by: candidateScale)
      let fits = corners.allSatisfy {
        hypot(candidate.x + $0.x, candidate.y + $0.y) <= innerRadius
      }
      if fits {
        lowerBound = candidateScale
      } else {
        upperBound = candidateScale
      }
    }
    return point.scaled(by: lowerBound)
  }
}

extension CGPoint {
  fileprivate func scaled(by amount: CGFloat) -> CGPoint {
    CGPoint(x: x * amount, y: y * amount)
  }
}

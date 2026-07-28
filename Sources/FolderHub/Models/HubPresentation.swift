import CoreGraphics
import Foundation

enum HubInteractionPhase: Equatable, Sendable {
  case idle
  case selecting
  case expanded
  case collapsing
}

enum HubSizingPolicy {
  static let contentInset: CGFloat = 5
  static let maximumDiameter: CGFloat = 208

  static func minimumDiameter(forFolderCount count: Int) -> CGFloat {
    switch count {
    case 0:
      128
    case 1:
      104
    case 2:
      124
    case 3...4:
      152
    case 5...8:
      176
    default:
      208
    }
  }
}

struct HubPresentationMetrics: Equatable, Sendable {
  static let branchSize = CGSize(width: 190, height: 144)
  static let rootSize = branchSize
  static let bubbleCornerRadius: CGFloat = 24
  static let branchInteractionOutset: CGFloat = 12
  static let branchDetachThreshold: CGFloat = 44
  static let padding: CGFloat = 18
  static var branchWindowSize: CGSize {
    branchWindowSize(for: branchSize)
  }

  static func branchWindowSize(for visualSize: CGSize) -> CGSize {
    CGSize(
      width: visualSize.width + branchInteractionOutset * 2,
      height: visualSize.height + branchInteractionOutset * 2
    )
  }

  let hubSize: CGSize
  let branchVisualSize: CGSize
  let canvasSize: CGSize
  let hubCenter: CGPoint
  let branchCenter: CGPoint?

  static func collapsed(
    hubSize: CGSize = rootSize
  ) -> HubPresentationMetrics {
    HubPresentationMetrics(
      hubSize: hubSize,
      branchVisualSize: hubSize,
      canvasSize: CGSize(
        width: hubSize.width + padding * 2,
        height: hubSize.height + padding * 2
      ),
      hubCenter: CGPoint(
        x: hubSize.width / 2 + padding,
        y: hubSize.height / 2 + padding
      ),
      branchCenter: nil
    )
  }

  static func expanded(
    hubSize: CGSize = rootSize,
    direction rawDirection: CGVector
  ) -> HubPresentationMetrics {
    let direction = rawDirection.normalized(or: CGVector(dx: 1, dy: 0))
    let hubHalfExtent =
      abs(direction.dx) * hubSize.width / 2
      + abs(direction.dy) * hubSize.height / 2
    let branchHalfExtent =
      abs(direction.dx) * hubSize.width / 2
      + abs(direction.dy) * hubSize.height / 2
    let branchDistance = hubHalfExtent + branchHalfExtent + 18
    let branchCenterFromHub = CGPoint(
      x: direction.dx * branchDistance,
      y: direction.dy * branchDistance
    )

    let hubRect = CGRect(
      x: -hubSize.width / 2,
      y: -hubSize.height / 2,
      width: hubSize.width,
      height: hubSize.height
    )
    let branchRect = CGRect(
      x: branchCenterFromHub.x - hubSize.width / 2,
      y: branchCenterFromHub.y - hubSize.height / 2,
      width: hubSize.width,
      height: hubSize.height
    )
    let expandedPadding =
      padding + branchInteractionOutset + branchDetachThreshold
    let bounds = hubRect.union(branchRect).insetBy(
      dx: -expandedPadding,
      dy: -expandedPadding
    )

    let translation = CGPoint(x: -bounds.minX, y: -bounds.minY)
    return HubPresentationMetrics(
      hubSize: hubSize,
      branchVisualSize: hubSize,
      canvasSize: bounds.size,
      hubCenter: translation,
      branchCenter: CGPoint(
        x: branchCenterFromHub.x + translation.x,
        y: branchCenterFromHub.y + translation.y
      )
    )
  }
}

enum BubbleResizePolicy {
  static func clamped(_ proposed: CGSize) -> CGSize {
    CGSize(
      width: max(HubPresentationMetrics.rootSize.width, proposed.width),
      height: max(HubPresentationMetrics.rootSize.height, proposed.height)
    )
  }
}

enum BranchDragPolicy {
  static func shouldDetach(_ offset: CGSize) -> Bool {
    hypot(offset.width, offset.height)
      >= HubPresentationMetrics.branchDetachThreshold
  }

  static func destination(
    settledOffset: CGSize,
    translation: CGSize
  ) -> CGSize {
    CGSize(
      width: settledOffset.width + translation.width,
      height: settledOffset.height + translation.height
    )
  }
}

extension CGVector {
  var magnitude: CGFloat {
    sqrt(dx * dx + dy * dy)
  }

  func normalized(or fallback: CGVector) -> CGVector {
    let length = magnitude
    guard length > 0.0001 else { return fallback }
    return CGVector(dx: dx / length, dy: dy / length)
  }
}

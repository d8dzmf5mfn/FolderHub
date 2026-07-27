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
  static let branchInteractionOutset: CGFloat = 12
  static let branchDragLimit: CGFloat = 72
  static let branchDetachThreshold: CGFloat = 58
  static let padding: CGFloat = 18

  let hubDiameter: CGFloat
  let canvasSize: CGSize
  let hubCenter: CGPoint
  let branchCenter: CGPoint?
  let connectorCenter: CGPoint?
  let connectorAngle: AngleValue

  static func collapsed(hubDiameter: CGFloat) -> HubPresentationMetrics {
    HubPresentationMetrics(
      hubDiameter: hubDiameter,
      canvasSize: CGSize(
        width: hubDiameter + padding * 2,
        height: hubDiameter + padding * 2
      ),
      hubCenter: CGPoint(
        x: hubDiameter / 2 + padding,
        y: hubDiameter / 2 + padding
      ),
      branchCenter: nil,
      connectorCenter: nil,
      connectorAngle: .zero
    )
  }

  static func expanded(
    hubDiameter: CGFloat,
    direction rawDirection: CGVector
  ) -> HubPresentationMetrics {
    let direction = rawDirection.normalized(or: CGVector(dx: 1, dy: 0))
    let hubRadius = hubDiameter / 2
    let branchHalfExtent =
      abs(direction.dx) * branchSize.width / 2
      + abs(direction.dy) * branchSize.height / 2
    let branchDistance = hubRadius + branchHalfExtent + 18
    let branchCenterFromHub = CGPoint(
      x: direction.dx * branchDistance,
      y: direction.dy * branchDistance
    )
    let connectorDistance = branchDistance / 2
    let connectorCenterFromHub = CGPoint(
      x: direction.dx * connectorDistance,
      y: direction.dy * connectorDistance
    )

    let hubRect = CGRect(
      x: -hubRadius,
      y: -hubRadius,
      width: hubDiameter,
      height: hubDiameter
    )
    let branchRect = CGRect(
      x: branchCenterFromHub.x - branchSize.width / 2,
      y: branchCenterFromHub.y - branchSize.height / 2,
      width: branchSize.width,
      height: branchSize.height
    )
    let expandedPadding =
      padding + branchInteractionOutset + branchDragLimit
    let bounds = hubRect.union(branchRect).insetBy(
      dx: -expandedPadding,
      dy: -expandedPadding
    )

    let translation = CGPoint(x: -bounds.minX, y: -bounds.minY)
    return HubPresentationMetrics(
      hubDiameter: hubDiameter,
      canvasSize: bounds.size,
      hubCenter: translation,
      branchCenter: CGPoint(
        x: branchCenterFromHub.x + translation.x,
        y: branchCenterFromHub.y + translation.y
      ),
      connectorCenter: CGPoint(
        x: connectorCenterFromHub.x + translation.x,
        y: connectorCenterFromHub.y + translation.y
      ),
      connectorAngle: AngleValue(
        radians: atan2(direction.dy, direction.dx)
      )
    )
  }
}

enum BranchDragPolicy {
  static func shouldDetach(_ offset: CGSize) -> Bool {
    hypot(offset.width, offset.height)
      >= HubPresentationMetrics.branchDetachThreshold
  }

  static func resisted(_ translation: CGSize) -> CGSize {
    CGSize(
      width: translation.width * 0.86,
      height: translation.height * 0.86
    )
  }

  static func clamped(_ offset: CGSize) -> CGSize {
    let magnitude = hypot(offset.width, offset.height)
    let limit = HubPresentationMetrics.branchDragLimit
    guard magnitude > limit, magnitude > 0 else {
      return offset
    }
    let scale = limit / magnitude
    return CGSize(
      width: offset.width * scale,
      height: offset.height * scale
    )
  }
}

struct AngleValue: Equatable, Sendable {
  let radians: Double
  static let zero = AngleValue(radians: 0)
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

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
  static let branchGap: CGFloat = 18
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
  let canvasSize: CGSize
  let hubCenter: CGPoint

  static func collapsed(
    hubSize: CGSize = rootSize
  ) -> HubPresentationMetrics {
    HubPresentationMetrics(
      hubSize: hubSize,
      canvasSize: CGSize(
        width: hubSize.width + padding * 2,
        height: hubSize.height + padding * 2
      ),
      hubCenter: CGPoint(
        x: hubSize.width / 2 + padding,
        y: hubSize.height / 2 + padding
      )
    )
  }

  static func independentBranchCenter(
    hubCenter: CGPoint,
    hubSize: CGSize,
    branchSize: CGSize = branchSize
  ) -> CGPoint {
    CGPoint(
      x: hubCenter.x
        + hubSize.width / 2
        + branchGap
        + branchSize.width / 2,
      y: hubCenter.y
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

enum BubbleResizeDragPolicy {
  static func proposedSize(
    startSize: CGSize,
    startPointer: CGPoint,
    currentPointer: CGPoint
  ) -> CGSize {
    BubbleResizePolicy.clamped(
      CGSize(
        width: startSize.width + currentPointer.x - startPointer.x,
        height: startSize.height + startPointer.y - currentPointer.y
      )
    )
  }
}

enum BubblePanelResizePolicy {
  static func topLeftAnchoredFrame(
    from currentFrame: CGRect,
    to newSize: CGSize
  ) -> CGRect {
    CGRect(
      x: currentFrame.minX,
      y: currentFrame.maxY - newSize.height,
      width: newSize.width,
      height: newSize.height
    )
  }
}

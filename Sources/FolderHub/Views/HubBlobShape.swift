import CoreGraphics
import SwiftUI

struct HubBlobShape: Shape {
  var metrics: HubPresentationMetrics
  var hubSize: CGSize
  var progress: CGFloat
  var interactionOutset: CGFloat = 0
  var branchOffset: CGSize = .zero

  var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>
  {
    get {
      AnimatablePair(
        progress,
        AnimatablePair(branchOffset.width, branchOffset.height)
      )
    }
    set {
      progress = newValue.first
      branchOffset = CGSize(
        width: newValue.second.first,
        height: newValue.second.second
      )
    }
  }

  func path(in rect: CGRect) -> Path {
    let hubRect = CGRect(
      x: metrics.hubCenter.x - hubSize.width / 2,
      y: metrics.hubCenter.y - hubSize.height / 2,
      width: hubSize.width,
      height: hubSize.height
    )
    var result = Path(
      roundedRect: hubRect,
      cornerRadius: HubPresentationMetrics.bubbleCornerRadius
    )

    guard let baseBranchCenter = metrics.branchCenter else {
      return result
    }

    let finalBranchCenter = CGPoint(
      x: baseBranchCenter.x + branchOffset.width,
      y: baseBranchCenter.y + branchOffset.height
    )
    let amount = min(max(progress, 0), 1)
    guard amount > 0.001 else { return result }
    let branchCenter = CGPoint(
      x: metrics.hubCenter.x
        + (finalBranchCenter.x - metrics.hubCenter.x) * amount,
      y: metrics.hubCenter.y
        + (finalBranchCenter.y - metrics.hubCenter.y) * amount
    )
    let scale = 0.72 + 0.28 * amount
    let branchWidth = HubPresentationMetrics.branchSize.width * scale
    let branchHeight = HubPresentationMetrics.branchSize.height * scale
    let branchRect = CGRect(
      x: branchCenter.x - branchWidth / 2,
      y: branchCenter.y - branchHeight / 2,
      width: branchWidth,
      height: branchHeight
    )
    .insetBy(
      dx: -interactionOutset * min(amount, 1),
      dy: -interactionOutset * min(amount, 1)
    )
    let branch = Path(
      roundedRect: branchRect,
      cornerRadius:
        HubPresentationMetrics.bubbleCornerRadius * scale
    )

    result = result.union(branch)
    return result
  }
}

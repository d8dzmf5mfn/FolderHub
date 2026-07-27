import CoreGraphics
import SwiftUI

struct HubBlobShape: Shape {
  var metrics: HubPresentationMetrics
  var hubDiameter: CGFloat
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
    let hubRadius = hubDiameter / 2
    let hubRect = CGRect(
      x: metrics.hubCenter.x - hubRadius,
      y: metrics.hubCenter.y - hubRadius,
      width: hubDiameter,
      height: hubDiameter
    )
    var result = Path(ellipseIn: hubRect)

    guard let baseBranchCenter = metrics.branchCenter else {
      return result
    }

    let finalBranchCenter = CGPoint(
      x: baseBranchCenter.x + branchOffset.width,
      y: baseBranchCenter.y + branchOffset.height
    )
    let amount = min(max(progress, 0), 1.08)
    let direction = CGVector(
      dx: finalBranchCenter.x - metrics.hubCenter.x,
      dy: finalBranchCenter.y - metrics.hubCenter.y
    ).normalized(or: CGVector(dx: 1, dy: 0))
    let origin = CGPoint(
      x: metrics.hubCenter.x + direction.dx * (hubRadius - 18),
      y: metrics.hubCenter.y + direction.dy * (hubRadius - 18)
    )
    let branchCenter = CGPoint(
      x: origin.x + (finalBranchCenter.x - origin.x) * amount,
      y: origin.y + (finalBranchCenter.y - origin.y) * amount
    )
    let branchWidth =
      26 + (HubPresentationMetrics.branchSize.width - 26) * amount
    let branchHeight =
      26 + (HubPresentationMetrics.branchSize.height - 26) * amount
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
    let cornerRadius =
      min(branchRect.width, branchRect.height)
      * (0.5 - 0.24 * min(amount, 1))

    let neck = organicConnector(
      hubCenter: metrics.hubCenter,
      branchCenter: branchCenter,
      direction: direction,
      hubRadius: hubRadius,
      amount: amount
    )
    let branch = Path(
      roundedRect: branchRect,
      cornerRadius: cornerRadius
    )

    result = result.union(neck)
    result = result.union(branch)
    return result
  }

  private func organicConnector(
    hubCenter: CGPoint,
    branchCenter: CGPoint,
    direction: CGVector,
    hubRadius: CGFloat,
    amount: CGFloat
  ) -> Path {
    let clampedAmount = min(amount, 1)
    let normal = CGVector(dx: -direction.dy, dy: direction.dx)
    let start = CGPoint(
      x: hubCenter.x + direction.dx * (hubRadius - 70),
      y: hubCenter.y + direction.dy * (hubRadius - 70)
    )
    let endInset = 54 + 12 * clampedAmount
    let end = CGPoint(
      x: branchCenter.x - direction.dx * endInset,
      y: branchCenter.y - direction.dy * endInset
    )
    let rootHalfWidth = 14 + 34 * clampedAmount
    let tipHalfWidth = 12 + 26 * clampedAmount
    let startTop = start.offset(by: normal, distance: rootHalfWidth)
    let startBottom = start.offset(by: normal, distance: -rootHalfWidth)
    let endTop = end.offset(by: normal, distance: tipHalfWidth)
    let endBottom = end.offset(by: normal, distance: -tipHalfWidth)
    let length = max(
      1,
      hypot(end.x - start.x, end.y - start.y)
    )
    let firstControlDistance = length * 0.42
    let secondControlDistance = length * 0.36

    var path = Path()
    path.move(to: startTop)
    path.addCurve(
      to: endTop,
      control1: startTop.offset(
        by: direction,
        distance: firstControlDistance
      ),
      control2: endTop.offset(
        by: direction,
        distance: -secondControlDistance
      )
    )
    path.addLine(to: endBottom)
    path.addCurve(
      to: startBottom,
      control1: endBottom.offset(
        by: direction,
        distance: -secondControlDistance
      ),
      control2: startBottom.offset(
        by: direction,
        distance: firstControlDistance
      )
    )
    path.closeSubpath()
    return path
  }
}

extension CGPoint {
  fileprivate func offset(by vector: CGVector, distance: CGFloat) -> CGPoint {
    CGPoint(
      x: x + vector.dx * distance,
      y: y + vector.dy * distance
    )
  }
}

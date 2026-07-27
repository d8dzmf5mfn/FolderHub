import CoreGraphics
import Testing

@testable import FolderHub

@Suite("Hub presentation geometry")
struct HubPresentationTests {
  @Test(
    "Expanded branch stays in the selected direction",
    arguments: [
      CGVector(dx: 1, dy: 0),
      CGVector(dx: -1, dy: 0),
      CGVector(dx: 0, dy: 1),
      CGVector(dx: 0.7, dy: -0.4),
    ]
  )
  func branchDirection(_ direction: CGVector) {
    let metrics = HubPresentationMetrics.expanded(
      hubDiameter: 152,
      direction: direction
    )
    let branch = metrics.branchCenter!
    let offset = CGVector(
      dx: branch.x - metrics.hubCenter.x,
      dy: branch.y - metrics.hubCenter.y
    )

    #expect(offset.dx * direction.dx + offset.dy * direction.dy > 0)
    #expect(metrics.canvasSize.width >= metrics.hubDiameter)
    #expect(metrics.canvasSize.height >= metrics.hubDiameter)
  }

  @Test("Zero direction uses the right-side fallback")
  func zeroDirectionFallback() {
    let metrics = HubPresentationMetrics.expanded(
      hubDiameter: 152,
      direction: CGVector(dx: 0, dy: 0)
    )
    #expect(metrics.branchCenter!.x > metrics.hubCenter.x)
    #expect(metrics.branchCenter!.y == metrics.hubCenter.y)
  }

  @Test("Expanded glass path is one connected pull from hub to branch")
  func connectedGlassPath() {
    let metrics = HubPresentationMetrics.expanded(
      hubDiameter: 208,
      direction: CGVector(dx: 0.8, dy: 0.45)
    )
    let shape = HubBlobShape(
      metrics: metrics,
      hubDiameter: metrics.hubDiameter,
      progress: 1
    )
    let path = shape.path(
      in: CGRect(origin: .zero, size: metrics.canvasSize)
    )
    let branchCenter = metrics.branchCenter!

    #expect(path.contains(metrics.hubCenter))
    #expect(path.contains(branchCenter))

    for step in 0...10 {
      let amount = CGFloat(step) / 10
      let point = CGPoint(
        x: metrics.hubCenter.x
          + (branchCenter.x - metrics.hubCenter.x) * amount,
        y: metrics.hubCenter.y
          + (branchCenter.y - metrics.hubCenter.y) * amount
      )
      #expect(path.contains(point))
    }
  }

  @Test("Collapsed canvas follows the dynamic hub diameter")
  func collapsedCanvasSizing() {
    for diameter in [104.0, 140.0, 176.0, 208.0] {
      let metrics = HubPresentationMetrics.collapsed(
        hubDiameter: diameter
      )
      #expect(
        abs(
          metrics.canvasSize.width
            - diameter - HubPresentationMetrics.padding * 2
        ) < 0.001
      )
      #expect(
        abs(
          metrics.canvasSize.height
            - diameter - HubPresentationMetrics.padding * 2
        ) < 0.001
      )
    }
  }

  @Test("Branch interaction extends beyond the visible glass")
  func expandedBranchInteractionRegion() {
    let metrics = HubPresentationMetrics.expanded(
      hubDiameter: 140,
      direction: CGVector(dx: 1, dy: 0)
    )
    let visualShape = HubBlobShape(
      metrics: metrics,
      hubDiameter: metrics.hubDiameter,
      progress: 1
    )
    let interactionShape = HubBlobShape(
      metrics: metrics,
      hubDiameter: metrics.hubDiameter,
      progress: 1,
      interactionOutset:
        HubPresentationMetrics.branchInteractionOutset
    )
    let branchCenter = metrics.branchCenter!
    let expandedHitPoint = CGPoint(
      x: branchCenter.x
        + HubPresentationMetrics.branchSize.width / 2 + 8,
      y: branchCenter.y
    )

    #expect(
      !visualShape.path(
        in: CGRect(origin: .zero, size: metrics.canvasSize)
      ).contains(expandedHitPoint)
    )
    #expect(
      interactionShape.path(
        in: CGRect(origin: .zero, size: metrics.canvasSize)
      ).contains(expandedHitPoint)
    )
  }

  @Test("Dragged branch remains connected and inside its canvas")
  func draggedBranchGeometry() {
    let metrics = HubPresentationMetrics.expanded(
      hubDiameter: 140,
      direction: CGVector(dx: 0.8, dy: -0.35)
    )
    let offset = BranchDragPolicy.clamped(
      CGSize(width: 90, height: -60)
    )
    let shape = HubBlobShape(
      metrics: metrics,
      hubDiameter: metrics.hubDiameter,
      progress: 1,
      branchOffset: offset
    )
    let path = shape.path(
      in: CGRect(origin: .zero, size: metrics.canvasSize)
    )
    let draggedCenter = CGPoint(
      x: metrics.branchCenter!.x + offset.width,
      y: metrics.branchCenter!.y + offset.height
    )
    let bounds = path.boundingRect

    #expect(path.contains(metrics.hubCenter))
    #expect(path.contains(draggedCenter))
    #expect(bounds.minX >= 0)
    #expect(bounds.minY >= 0)
    #expect(bounds.maxX <= metrics.canvasSize.width)
    #expect(bounds.maxY <= metrics.canvasSize.height)
    #expect(
      hypot(offset.width, offset.height)
        <= HubPresentationMetrics.branchDragLimit + 0.001
    )
  }
}

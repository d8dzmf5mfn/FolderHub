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
    let metrics = HubPresentationMetrics.expanded(direction: direction)
    let branch = metrics.branchCenter!
    let offset = CGVector(
      dx: branch.x - metrics.hubCenter.x,
      dy: branch.y - metrics.hubCenter.y
    )

    #expect(offset.dx * direction.dx + offset.dy * direction.dy > 0)
    #expect(metrics.canvasSize.width >= metrics.hubSize.width)
    #expect(metrics.canvasSize.height >= metrics.hubSize.height)
  }

  @Test("Zero direction uses the right-side fallback")
  func zeroDirectionFallback() {
    let metrics = HubPresentationMetrics.expanded(
      direction: CGVector(dx: 0, dy: 0)
    )
    #expect(metrics.branchCenter!.x > metrics.hubCenter.x)
    #expect(metrics.branchCenter!.y == metrics.hubCenter.y)
  }

  @Test(
    "Root and branch stay disconnected throughout expansion",
    arguments: [CGFloat(0.1), 0.25, 0.5, 0.75, 1]
  )
  func disconnectedGlassPath(_ progress: CGFloat) {
    let metrics = HubPresentationMetrics.expanded(
      direction: CGVector(dx: 1, dy: 0)
    )
    let shape = HubBlobShape(
      metrics: metrics,
      hubSize: metrics.hubSize,
      progress: progress
    )
    let path = shape.path(
      in: CGRect(origin: .zero, size: metrics.canvasSize)
    )
    let branchCenter = metrics.branchCenter!
    let gapCenter = CGPoint(
      x: (metrics.hubCenter.x + branchCenter.x) / 2,
      y: (metrics.hubCenter.y + branchCenter.y) / 2
    )

    #expect(path.contains(metrics.hubCenter))
    #expect(path.contains(branchCenter))
    #expect(!path.contains(gapCenter))
  }

  @Test("Collapsed canvas follows the rounded rectangle root size")
  func collapsedCanvasSizing() {
    let metrics = HubPresentationMetrics.collapsed()
    let rootSize = HubPresentationMetrics.rootSize

    #expect(metrics.hubSize == rootSize)
    #expect(
      abs(
        metrics.canvasSize.width
          - rootSize.width - HubPresentationMetrics.padding * 2
      ) < 0.001
    )
    #expect(
      abs(
        metrics.canvasSize.height
          - rootSize.height - HubPresentationMetrics.padding * 2
      ) < 0.001
    )
  }

  @Test("Child bubble sizes change independently")
  @MainActor
  func independentBubbleSizes() {
    let parent = BubbleResizeState()
    let child = BubbleResizeState()

    parent.resize(to: CGSize(width: 260, height: 196))

    #expect(parent.size == CGSize(width: 260, height: 196))
    #expect(child.size == HubPresentationMetrics.branchSize)
  }

  @Test("Bubble resizing cannot shrink below the shared default")
  func minimumBubbleSize() {
    #expect(
      BubbleResizePolicy.clamped(CGSize(width: 120, height: 240))
        == CGSize(width: 190, height: 240)
    )
    #expect(
      BubbleResizePolicy.clamped(CGSize(width: 300, height: 90))
        == CGSize(width: 300, height: 144)
    )
  }

  @Test("Resize corner keeps a clear pointer target")
  func resizeCornerTarget() {
    #expect(BubbleResizeMetrics.hitSize >= 32)
    #expect(BubbleResizeMetrics.visualSize == 24)
    #expect(BubbleResizeMetrics.glyphSize == 13)
    #expect(BubbleResizeMetrics.hitSize > BubbleResizeMetrics.visualSize)
    #expect(BubbleResizeMetrics.visualSize > BubbleResizeMetrics.glyphSize)
    #expect(HubPresentationMetrics.bubbleCornerRadius == 24)
  }

  @Test("Branch interaction extends beyond the visible glass")
  func expandedBranchInteractionRegion() {
    let metrics = HubPresentationMetrics.expanded(
      direction: CGVector(dx: 1, dy: 0)
    )
    let visualShape = HubBlobShape(
      metrics: metrics,
      hubSize: metrics.hubSize,
      progress: 1
    )
    let interactionShape = HubBlobShape(
      metrics: metrics,
      hubSize: metrics.hubSize,
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

  @Test("Branch drag follows the pointer without a movement limit")
  func unrestrictedBranchDrag() {
    let translation = CGSize(width: 240, height: -180)
    let destination = BranchDragPolicy.destination(
      settledOffset: CGSize(width: 12, height: 8),
      translation: translation
    )

    #expect(destination == CGSize(width: 252, height: -172))
  }

  @Test("Branch detaches equally in every drag direction")
  func symmetricBranchDetach() {
    let threshold = HubPresentationMetrics.branchDetachThreshold

    #expect(BranchDragPolicy.shouldDetach(CGSize(width: 0, height: threshold)))
    #expect(BranchDragPolicy.shouldDetach(CGSize(width: 0, height: -threshold)))
    #expect(BranchDragPolicy.shouldDetach(CGSize(width: threshold, height: 0)))
    #expect(BranchDragPolicy.shouldDetach(CGSize(width: -threshold, height: 0)))
    #expect(
      !BranchDragPolicy.shouldDetach(
        CGSize(width: 0, height: threshold - 1)
      )
    )
  }
}

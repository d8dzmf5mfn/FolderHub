import CoreGraphics
import Testing

@testable import FolderHub

@Suite("Hub presentation geometry")
struct HubPresentationTests {
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

  @Test("First branch starts beside the Hub without sharing its canvas")
  func independentBranchPlacement() {
    let hubCenter = CGPoint(x: 400, y: 300)
    let hubSize = CGSize(width: 240, height: 180)
    let branchSize = CGSize(width: 190, height: 144)

    let branchCenter = HubPresentationMetrics.independentBranchCenter(
      hubCenter: hubCenter,
      hubSize: hubSize,
      branchSize: branchSize
    )

    #expect(branchCenter.y == hubCenter.y)
    #expect(
      branchCenter.x - branchSize.width / 2
        == hubCenter.x + hubSize.width / 2
        + HubPresentationMetrics.branchGap
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

  @Test("Resize drag uses stable screen coordinates without amplification")
  func stableScreenCoordinateResize() {
    let proposed = BubbleResizeDragPolicy.proposedSize(
      startSize: CGSize(width: 190, height: 144),
      startPointer: CGPoint(x: 500, y: 500),
      currentPointer: CGPoint(x: 560, y: 450)
    )

    #expect(proposed == CGSize(width: 250, height: 194))
  }

  @Test("Resize growth stays monotonic as the pointer moves down and right")
  func monotonicResizeGrowth() {
    let startSize = CGSize(width: 190, height: 144)
    let startPointer = CGPoint(x: 500, y: 500)
    let first = BubbleResizeDragPolicy.proposedSize(
      startSize: startSize,
      startPointer: startPointer,
      currentPointer: CGPoint(x: 520, y: 480)
    )
    let second = BubbleResizeDragPolicy.proposedSize(
      startSize: startSize,
      startPointer: startPointer,
      currentPointer: CGPoint(x: 540, y: 460)
    )

    #expect(second.width > first.width)
    #expect(second.height > first.height)
  }

  @Test("Panel resizing keeps its top-left corner fixed")
  func topLeftAnchoredPanelResize() {
    let currentFrame = CGRect(x: 100, y: 200, width: 214, height: 168)
    let resized = BubblePanelResizePolicy.topLeftAnchoredFrame(
      from: currentFrame,
      to: CGSize(width: 274, height: 218)
    )

    #expect(resized.minX == currentFrame.minX)
    #expect(resized.maxY == currentFrame.maxY)
    #expect(resized.size == CGSize(width: 274, height: 218))
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
}

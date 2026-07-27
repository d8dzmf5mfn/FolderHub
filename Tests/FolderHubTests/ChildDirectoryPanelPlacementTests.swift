import CoreGraphics
import Testing

@testable import FolderHub

@Suite("Child directory panel placement")
struct ChildDirectoryPanelPlacementTests {
  @Test("Places the child on the right when space is available")
  func placesOnRight() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)
    let parentFrame = CGRect(x: 300, y: 300, width: 190, height: 144)
    let size = CGSize(width: 214, height: 168)

    let frame = ChildDirectoryPanelPlacement.frame(
      size: size,
      adjacentTo: parentFrame,
      visibleFrame: visibleFrame
    )

    #expect(
      frame.minX
        == parentFrame.maxX - ChildDirectoryPanelPlacement.overlap
    )
    #expect(frame.midY == parentFrame.midY)
    #expect(visibleFrame.contains(frame))
  }

  @Test("Falls back to the left near the right display edge")
  func fallsBackToLeft() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 900, height: 700)
    let parentFrame = CGRect(x: 700, y: 260, width: 190, height: 144)
    let size = CGSize(width: 214, height: 168)

    let frame = ChildDirectoryPanelPlacement.frame(
      size: size,
      adjacentTo: parentFrame,
      visibleFrame: visibleFrame
    )

    #expect(
      frame.minX
        == parentFrame.minX - size.width
          + ChildDirectoryPanelPlacement.overlap
    )
    #expect(frame.midY == parentFrame.midY)
    #expect(visibleFrame.contains(frame))
  }

  @Test("Clamps the child inside a compact display")
  func clampsToVisibleFrame() {
    let visibleFrame = CGRect(x: 100, y: 80, width: 360, height: 260)
    let parentFrame = CGRect(x: 380, y: 250, width: 190, height: 144)
    let size = CGSize(width: 214, height: 168)

    let frame = ChildDirectoryPanelPlacement.frame(
      size: size,
      adjacentTo: parentFrame,
      visibleFrame: visibleFrame
    )

    #expect(visibleFrame.contains(frame))
  }
}

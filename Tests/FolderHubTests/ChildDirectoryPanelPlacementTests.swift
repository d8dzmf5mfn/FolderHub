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

  @Test("Places simultaneous sibling branches without overlap")
  func avoidsExistingSibling() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1400, height: 900)
    let parentFrame = CGRect(x: 550, y: 360, width: 190, height: 144)
    let size = CGSize(width: 214, height: 168)
    let first = ChildDirectoryPanelPlacement.frame(
      size: size,
      adjacentTo: parentFrame,
      visibleFrame: visibleFrame
    )

    let second = ChildDirectoryPanelPlacement.frame(
      size: size,
      adjacentTo: parentFrame,
      visibleFrame: visibleFrame,
      avoiding: [first]
    )

    #expect(!first.intersects(second))
    #expect(visibleFrame.contains(second))
  }

  @Test("Fans additional sibling branches around their parent")
  func fansMultipleSiblings() {
    let visibleFrame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    let parentFrame = CGRect(x: 650, y: 420, width: 190, height: 144)
    let size = CGSize(width: 214, height: 168)
    var frames: [CGRect] = []

    for _ in 0..<4 {
      frames.append(
        ChildDirectoryPanelPlacement.frame(
          size: size,
          adjacentTo: parentFrame,
          visibleFrame: visibleFrame,
          avoiding: frames
        )
      )
    }

    for index in frames.indices {
      for otherIndex in frames.indices where otherIndex > index {
        #expect(!frames[index].intersects(frames[otherIndex]))
      }
      #expect(visibleFrame.contains(frames[index]))
    }
  }
}

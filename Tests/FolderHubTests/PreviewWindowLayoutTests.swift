import CoreGraphics
import Testing

@testable import FolderHub

@Suite("Preview window layout")
struct PreviewWindowLayoutTests {
  @Test("Large preview stays centered inside the visible display")
  func largeDisplay() {
    let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let frame = PreviewWindowLayout.frame(in: visibleFrame)

    #expect(frame.width >= 720)
    #expect(frame.height >= 520)
    #expect(abs(frame.midX - visibleFrame.midX) < 0.001)
    #expect(abs(frame.midY - visibleFrame.midY) < 0.001)
    #expect(visibleFrame.contains(frame))
  }

  @Test("Preview shrinks to fit a compact display")
  func compactDisplay() {
    let visibleFrame = CGRect(x: 100, y: 80, width: 620, height: 480)
    let frame = PreviewWindowLayout.frame(in: visibleFrame)

    #expect(visibleFrame.contains(frame))
    #expect(frame.width == 492)
    #expect(frame.height == 372)
  }
}

import AppKit
import SwiftUI

struct WindowDragHitBox: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowDragHitView {
    WindowDragHitView()
  }

  func updateNSView(
    _ nsView: WindowDragHitView,
    context: Context
  ) {}
}

final class WindowDragHitView: NSView {
  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    addCursorRect(bounds, cursor: .openHand)
  }

  override func mouseEntered(with event: NSEvent) {
    NSCursor.openHand.set()
  }

  override func mouseExited(with event: NSEvent) {
    NSCursor.arrow.set()
  }
}

import AppKit
import SwiftUI

enum ChildDirectoryPanelPlacement {
  static let overlap: CGFloat = 16
  static let margin: CGFloat = 10

  static func frame(
    size: CGSize,
    adjacentTo parentFrame: CGRect,
    visibleFrame: CGRect
  ) -> CGRect {
    let available = visibleFrame.insetBy(dx: margin, dy: margin)
    let rightOriginX = parentFrame.maxX - overlap
    let leftOriginX = parentFrame.minX - size.width + overlap
    let preferredX =
      rightOriginX + size.width <= available.maxX
      ? rightOriginX
      : leftOriginX

    var origin = CGPoint(
      x: preferredX,
      y: parentFrame.midY - size.height / 2
    )
    origin.x = min(max(origin.x, available.minX), available.maxX - size.width)
    origin.y = min(max(origin.y, available.minY), available.maxY - size.height)
    return CGRect(origin: origin, size: size)
  }
}

@MainActor
final class ChildDirectoryPanelController {
  private let panel: HubPanel
  private let store: ChildDirectoryStore

  var frame: CGRect {
    panel.frame
  }

  init(
    directoryURL: URL,
    onOpenDirectory: @escaping (URL) -> Void,
    onClose: @escaping () -> Void
  ) {
    store = ChildDirectoryStore(directoryURL: directoryURL)
    let size = ChildDirectoryBubbleView.size
    panel = HubPanel(
      contentRect: CGRect(origin: .zero, size: size),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    panel.title = directoryURL.lastPathComponent
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isMovableByWindowBackground = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.acceptsMouseMovedEvents = true
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
    ]
    panel.level = .normal

    let hostingView = NSHostingView(
      rootView: ChildDirectoryBubbleView(store: store)
    )
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    store.onOpenDirectory = onOpenDirectory
    panel.onEscape = onClose
    panel.onBack = onClose
    panel.onQuickLook = { [weak store] in
      store?.previewSelectedItem()
    }
  }

  func show(adjacentTo parentFrame: CGRect) {
    let targetScreen =
      NSScreen.screens.first(where: {
        $0.visibleFrame.intersects(parentFrame)
      })
      ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let targetScreen else { return }

    let targetFrame = ChildDirectoryPanelPlacement.frame(
      size: panel.frame.size,
      adjacentTo: parentFrame,
      visibleFrame: targetScreen.visibleFrame
    )
    panel.setFrame(targetFrame, display: true)
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func close() {
    panel.orderOut(nil)
  }
}

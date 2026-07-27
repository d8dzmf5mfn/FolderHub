import AppKit
import SwiftUI

enum ChildDirectoryPanelPlacement {
  static let overlap: CGFloat = 16
  static let margin: CGFloat = 10

  static func frame(
    size: CGSize,
    adjacentTo parentFrame: CGRect,
    visibleFrame: CGRect,
    avoiding occupiedFrames: [CGRect] = []
  ) -> CGRect {
    let available = visibleFrame.insetBy(dx: margin, dy: margin)
    let rightOriginX = parentFrame.maxX - overlap
    let leftOriginX = parentFrame.minX - size.width + overlap
    let preferredOrigins =
      rightOriginX + size.width <= available.maxX
      ? [rightOriginX, leftOriginX]
      : [leftOriginX, rightOriginX]
    let verticalStep = max(size.height - overlap, 48)
    let verticalOffsets: [CGFloat] = [
      0,
      verticalStep,
      -verticalStep,
      verticalStep * 2,
      -verticalStep * 2,
      verticalStep * 3,
      -verticalStep * 3,
    ]

    var bestFrame: CGRect?
    var bestScore = CGFloat.greatestFiniteMagnitude

    for (sideIndex, originX) in preferredOrigins.enumerated() {
      for verticalOffset in verticalOffsets {
        var origin = CGPoint(
          x: originX,
          y: parentFrame.midY - size.height / 2 + verticalOffset
        )
        origin.x = min(
          max(origin.x, available.minX),
          available.maxX - size.width
        )
        origin.y = min(
          max(origin.y, available.minY),
          available.maxY - size.height
        )
        let candidate = CGRect(origin: origin, size: size)
        let overlapArea = occupiedFrames.reduce(CGFloat.zero) {
          partialResult,
          occupiedFrame in
          let intersection = candidate.intersection(occupiedFrame)
          guard !intersection.isNull else { return partialResult }
          return partialResult + intersection.width * intersection.height
        }
        let score =
          overlapArea * 10_000
          + CGFloat(sideIndex) * 5
          + abs(verticalOffset) * 0.1
        if score < bestScore {
          bestScore = score
          bestFrame = candidate
        }
      }
    }

    return bestFrame
      ?? CGRect(
        x: available.minX,
        y: available.minY,
        width: size.width,
        height: size.height
      )
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
    panel.level = FolderHubWindowPinning.level(isPinned: false)

    let hostingView = NSHostingView(
      rootView: ChildDirectoryBubbleView(store: store)
    )
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    store.onOpenDirectory = onOpenDirectory
    store.onClose = onClose
    store.onPinChange = { [weak self] isPinned in
      self?.panel.level = FolderHubWindowPinning.level(isPinned: isPinned)
    }
    panel.onQuickLook = { [weak store] in
      store?.previewSelectedItem()
    }
  }

  func show(
    adjacentTo parentFrame: CGRect,
    avoiding occupiedFrames: [CGRect]
  ) {
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
      visibleFrame: targetScreen.visibleFrame,
      avoiding: occupiedFrames
    )
    panel.setFrame(targetFrame, display: true)
    bringToFront()
  }

  func bringToFront() {
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func close() {
    panel.orderOut(nil)
  }
}

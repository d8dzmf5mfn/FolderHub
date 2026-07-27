import AppKit
import SwiftUI

@MainActor
final class DetachedBranchPanelController {
  private let panel: HubPanel
  private var dragStartOrigin: CGPoint?

  var frame: CGRect {
    panel.frame
  }

  init(
    store: HubStore,
    onReturnToHub: @escaping () -> Void
  ) {
    let outset = HubPresentationMetrics.branchInteractionOutset
    let size = CGSize(
      width: HubPresentationMetrics.branchSize.width + outset * 2,
      height: HubPresentationMetrics.branchSize.height + outset * 2
    )
    panel = HubPanel(
      contentRect: CGRect(origin: .zero, size: size),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    panel.title = "Detached Folder Bubble"
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isMovableByWindowBackground = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.acceptsMouseMovedEvents = true
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
    ]
    panel.level = .normal

    let rootView = DetachedBranchBubbleView(
      store: store,
      onReturnToHub: onReturnToHub,
      onDragChanged: { _ in },
      onDragEnded: { _ in }
    )
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    hostingView.rootView = DetachedBranchBubbleView(
      store: store,
      onReturnToHub: onReturnToHub,
      onDragChanged: { [weak self] translation in
        self?.movePanel(with: translation)
      },
      onDragEnded: { [weak self] _ in
        self?.dragStartOrigin = nil
      }
    )

    panel.onEscape = onReturnToHub
    panel.onBack = { [weak store] in
      store?.navigateBack()
    }
    panel.onQuickLook = { [weak store] in
      store?.previewSelectedItem()
    }
    panel.onTrash = { [weak store] in
      store?.trashSelectedItem()
    }
  }

  func show(centeredAt point: CGPoint) {
    let targetScreen =
      NSScreen.screens.first { $0.frame.contains(point) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let targetScreen else { return }

    let size = panel.frame.size
    let available = targetScreen.visibleFrame.insetBy(dx: 10, dy: 10)
    var origin = CGPoint(
      x: point.x - size.width / 2,
      y: point.y - size.height / 2
    )
    origin.x = min(max(origin.x, available.minX), available.maxX - size.width)
    origin.y = min(max(origin.y, available.minY), available.maxY - size.height)
    panel.setFrameOrigin(origin)
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func close() {
    panel.orderOut(nil)
  }

  private func movePanel(with translation: CGSize) {
    if dragStartOrigin == nil {
      dragStartOrigin = panel.frame.origin
    }
    guard let dragStartOrigin else { return }
    panel.setFrameOrigin(
      CGPoint(
        x: dragStartOrigin.x + translation.width,
        y: dragStartOrigin.y - translation.height
      )
    )
  }
}

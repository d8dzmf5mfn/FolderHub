import AppKit
import SwiftUI

@MainActor
final class DetachedBranchPanelController {
  private let panel: HubPanel
  private let resizeState: BubbleResizeState
  private var dragStartOrigin: CGPoint?

  var frame: CGRect {
    panel.frame
  }

  init(
    store: HubStore,
    onReturnToHub: @escaping () -> Void
  ) {
    resizeState = BubbleResizeState()
    let size = HubPresentationMetrics.branchWindowSize(
      for: resizeState.size
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
      resizeState: resizeState,
      onReturnToHub: onReturnToHub,
      onDragChanged: { _ in },
      onDragEnded: { _ in }
    )
    let hostingView = FirstMouseHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    hostingView.rootView = DetachedBranchBubbleView(
      store: store,
      resizeState: resizeState,
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
    resizeState.onResize = { [weak self] visualSize in
      self?.resizePanel(to: visualSize)
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

  private func resizePanel(to visualSize: CGSize) {
    let newSize = HubPresentationMetrics.branchWindowSize(
      for: visualSize
    )
    guard panel.frame.size != newSize else { return }
    let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    panel.setFrame(
      CGRect(
        x: center.x - newSize.width / 2,
        y: center.y - newSize.height / 2,
        width: newSize.width,
        height: newSize.height
      ),
      display: true
    )
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

import AppKit
import SwiftUI

struct DraggableBranchHost: NSViewRepresentable {
  let store: HubStore
  var onChanged: (CGSize) -> Void
  var onEnded: (CGSize) -> Void
  var onHoverChanged: (Bool) -> Void = { _ in }
  var onPressChanged: (Bool) -> Void = { _ in }
  var tracksMovingWindow = false

  func makeNSView(context: Context) -> DraggableBranchContainerView {
    let container = DraggableBranchContainerView()
    container.install(rootView: BranchView(store: store))
    container.configure(
      onChanged: onChanged,
      onEnded: onEnded,
      onHoverChanged: onHoverChanged,
      onPressChanged: onPressChanged,
      tracksMovingWindow: tracksMovingWindow
    )
    return container
  }

  func updateNSView(
    _ nsView: DraggableBranchContainerView,
    context: Context
  ) {
    nsView.update(rootView: BranchView(store: store))
    nsView.configure(
      onChanged: onChanged,
      onEnded: onEnded,
      onHoverChanged: onHoverChanged,
      onPressChanged: onPressChanged,
      tracksMovingWindow: tracksMovingWindow
    )
  }

  static func dismantleNSView(
    _ nsView: DraggableBranchContainerView,
    coordinator: Void
  ) {
    nsView.prepareForRemoval()
  }
}

final class DraggableBranchContainerView:
  NSView,
  NSGestureRecognizerDelegate
{
  private var hostingView: BranchHostingView?
  private var hoverTrackingArea: NSTrackingArea?
  private var dragStartScreenPoint: CGPoint?
  private var lastTranslation = CGSize.zero

  private var onChanged: (CGSize) -> Void = { _ in }
  private var onEnded: (CGSize) -> Void = { _ in }
  private var onHoverChanged: (Bool) -> Void = { _ in }
  private var onPressChanged: (Bool) -> Void = { _ in }
  private var tracksMovingWindow = false

  private(set) var isPointerInside = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    let recognizer = NSPanGestureRecognizer(
      target: self,
      action: #selector(handlePan(_:))
    )
    recognizer.buttonMask = 0x1
    recognizer.delegate = self
    recognizer.delaysPrimaryMouseButtonEvents = false
    addGestureRecognizer(recognizer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override var isFlipped: Bool {
    false
  }

  func install(rootView: BranchView) {
    let hostingView = BranchHostingView(rootView: rootView)
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  func update(rootView: BranchView) {
    hostingView?.rootView = rootView
  }

  func configure(
    onChanged: @escaping (CGSize) -> Void,
    onEnded: @escaping (CGSize) -> Void,
    onHoverChanged: @escaping (Bool) -> Void,
    onPressChanged: @escaping (Bool) -> Void,
    tracksMovingWindow: Bool = false
  ) {
    self.onChanged = onChanged
    self.onEnded = onEnded
    self.onHoverChanged = onHoverChanged
    self.onPressChanged = onPressChanged
    self.tracksMovingWindow = tracksMovingWindow
  }

  func prepareForRemoval() {
    onHoverChanged(false)
    onPressChanged(false)
    NSCursor.arrow.set()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.acceptsMouseMovedEvents = true
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let hoverTrackingArea {
      removeTrackingArea(hoverTrackingArea)
    }
    let trackingArea = NSTrackingArea(
      rect: DragCollisionMetrics.branchHitRect(in: bounds),
      options: [.mouseEnteredAndExited, .activeAlways],
      owner: self
    )
    addTrackingArea(trackingArea)
    hoverTrackingArea = trackingArea
  }

  override func resetCursorRects() {
    super.resetCursorRects()
    addCursorRect(
      DragCollisionMetrics.branchHitRect(in: bounds),
      cursor: .openHand
    )
  }

  override func mouseEntered(with event: NSEvent) {
    isPointerInside = true
    onHoverChanged(true)
    NSCursor.openHand.set()
  }

  override func mouseExited(with event: NSEvent) {
    isPointerInside = false
    onHoverChanged(false)
    NSCursor.arrow.set()
  }

  func gestureRecognizer(
    _ gestureRecognizer: NSGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
      NSGestureRecognizer
  ) -> Bool {
    true
  }

  func gestureRecognizerShouldBegin(
    _ gestureRecognizer: NSGestureRecognizer
  ) -> Bool {
    let location = gestureRecognizer.location(in: self)
    return DragCollisionMetrics.branchHitRect(in: bounds)
      .contains(location)
  }

  @objc
  private func handlePan(_ recognizer: NSPanGestureRecognizer) {
    switch recognizer.state {
    case .began:
      dragStartScreenPoint = NSEvent.mouseLocation
      lastTranslation = .zero
      onPressChanged(true)
      NSCursor.closedHand.set()
      onChanged(.zero)

    case .changed:
      let translation: CGSize
      if tracksMovingWindow {
        guard let dragStartScreenPoint else { return }
        let currentPoint = NSEvent.mouseLocation
        translation = CGSize(
          width: currentPoint.x - dragStartScreenPoint.x,
          height: dragStartScreenPoint.y - currentPoint.y
        )
      } else {
        let appKitTranslation = recognizer.translation(in: self)
        translation = CGSize(
          width: appKitTranslation.x,
          height: -appKitTranslation.y
        )
      }
      lastTranslation = translation
      onChanged(translation)

    case .ended:
      let translation = lastTranslation
      resetDragState()
      onEnded(translation)

    case .cancelled, .failed:
      resetDragState()
      onEnded(.zero)

    default:
      break
    }
  }

  private func resetDragState() {
    dragStartScreenPoint = nil
    lastTranslation = .zero
    onPressChanged(false)
    if isPointerInside {
      NSCursor.openHand.set()
    } else {
      NSCursor.arrow.set()
    }
  }
}

private final class BranchHostingView: NSHostingView<BranchView> {
  override var mouseDownCanMoveWindow: Bool {
    false
  }
}

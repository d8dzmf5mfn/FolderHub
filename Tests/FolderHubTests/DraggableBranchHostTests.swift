import AppKit
import Testing

@testable import FolderHub

@Suite("Draggable branch host")
@MainActor
struct DraggableBranchHostTests {
  @Test("Pan reaches container through a child hit target")
  func panThroughChildView() {
    let panel = NSPanel(
      contentRect: CGRect(x: 0, y: 0, width: 260, height: 180),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isMovableByWindowBackground = false

    let container = DraggableBranchContainerView(
      frame: CGRect(x: 0, y: 0, width: 260, height: 180)
    )
    container.install(rootView: BranchView(store: .shared))
    panel.contentView = container

    var changes: [CGSize] = []
    var endingTranslation: CGSize?
    var pressStates: [Bool] = []
    container.configure(
      onChanged: { changes.append($0) },
      onEnded: { endingTranslation = $0 },
      onHoverChanged: { _ in },
      onPressChanged: { pressStates.append($0) }
    )
    panel.orderFront(nil)

    defer {
      container.prepareForRemoval()
      panel.orderOut(nil)
    }

    let start = CGPoint(x: 130, y: 165)
    let activationPoint = CGPoint(x: 134, y: 163)
    let end = CGPoint(x: 196, y: 129)
    sendMouseEvent(
      .leftMouseDown,
      at: start,
      to: panel,
      eventNumber: 1
    )
    sendMouseEvent(
      .leftMouseDragged,
      at: activationPoint,
      to: panel,
      eventNumber: 2
    )
    sendMouseEvent(
      .leftMouseDragged,
      at: end,
      to: panel,
      eventNumber: 3
    )
    sendMouseEvent(
      .leftMouseUp,
      at: end,
      to: panel,
      eventNumber: 4
    )

    #expect(changes.isEmpty == false)
    #expect(changes.last == CGSize(width: 66, height: 36))
    #expect(endingTranslation == CGSize(width: 66, height: 36))
    if let endingTranslation {
      #expect(BranchDragPolicy.shouldDetach(endingTranslation))
    }
    #expect(pressStates.contains(true))
    #expect(pressStates.last == false)
  }

  @Test("Pan outside the top collision box does not drag")
  func ignoresPanOutsideHandle() {
    let panel = NSPanel(
      contentRect: CGRect(x: 0, y: 0, width: 260, height: 180),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    let container = DraggableBranchContainerView(
      frame: CGRect(x: 0, y: 0, width: 260, height: 180)
    )
    container.install(rootView: BranchView(store: .shared))
    panel.contentView = container

    var changes: [CGSize] = []
    container.configure(
      onChanged: { changes.append($0) },
      onEnded: { _ in },
      onHoverChanged: { _ in },
      onPressChanged: { _ in }
    )
    panel.orderFront(nil)

    defer {
      container.prepareForRemoval()
      panel.orderOut(nil)
    }

    sendMouseEvent(
      .leftMouseDown,
      at: CGPoint(x: 80, y: 90),
      to: panel,
      eventNumber: 1
    )
    sendMouseEvent(
      .leftMouseDragged,
      at: CGPoint(x: 146, y: 54),
      to: panel,
      eventNumber: 2
    )
    sendMouseEvent(
      .leftMouseUp,
      at: CGPoint(x: 146, y: 54),
      to: panel,
      eventNumber: 3
    )

    #expect(changes.isEmpty)
  }

  @Test("Branch container cannot move its panel background")
  func preventsPanelBackgroundMove() {
    let container = DraggableBranchContainerView()
    #expect(container.mouseDownCanMoveWindow == false)
  }

  @Test("Window drag collision view receives its mouse-down event")
  func windowDragHitBoxReceivesMouseDown() {
    let panel = DragRecordingPanel(
      contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    let view = WindowDragHitView(
      frame: CGRect(
        origin: .zero,
        size: CGSize(
          width: DragCollisionMetrics.hubHitDiameter,
          height: DragCollisionMetrics.hubHitDiameter
        )
      )
    )
    panel.contentView = view
    guard
      let event = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: CGPoint(x: 16, y: 16),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: panel.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
      )
    else {
      Issue.record("Failed to create a mouse-down event")
      return
    }

    view.mouseDown(with: event)

    #expect(panel.didPerformDrag)
    #expect(view.mouseDownCanMoveWindow == false)
  }

  private func sendMouseEvent(
    _ type: NSEvent.EventType,
    at point: CGPoint,
    to panel: NSPanel,
    eventNumber: Int
  ) {
    guard
      let event = NSEvent.mouseEvent(
        with: type,
        location: point,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: panel.windowNumber,
        context: nil,
        eventNumber: eventNumber,
        clickCount: 1,
        pressure: type == .leftMouseUp ? 0 : 1
      )
    else {
      Issue.record("Failed to create \(type) event")
      return
    }
    NSApplication.shared.sendEvent(event)
  }
}

private final class DragRecordingPanel: NSPanel {
  private(set) var didPerformDrag = false

  override func performDrag(with event: NSEvent) {
    didPerformDrag = true
  }
}

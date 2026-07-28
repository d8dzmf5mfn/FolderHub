import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class DesktopPanelController: NSObject, NSWindowDelegate {
  private let store: HubStore
  private let panel: HubPanel
  private var metrics: HubPresentationMetrics
  private var globalMouseMonitor: Any?
  private var detachedBranchController: DetachedBranchPanelController?
  private var childDirectoryHierarchy = ChildDirectoryHierarchy()
  private var childDirectoryControllers: [UUID: ChildDirectoryPanelController] = [:]
  private var isUpdatingFrame = false

  init(store: HubStore) {
    self.store = store
    let initialMetrics = store.presentationMetrics
    metrics = initialMetrics
    panel = HubPanel(
      contentRect: CGRect(origin: .zero, size: initialMetrics.canvasSize),
      styleMask: HubWindowControls.centerPanelStyleMask,
      backing: .buffered,
      defer: false
    )
    super.init()

    configurePanel()
    let hostingView = FirstMouseHostingView(
      rootView: HubRootView(store: store)
    )
    hostingView.frame = panel.contentView?.bounds ?? .zero
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView
    panel.delegate = self

    store.onPresentationMetricsChange = { [weak self] metrics, animated in
      self?.apply(metrics: metrics, animated: animated)
    }
    store.onShowHub = { [weak self] in
      self?.show()
    }
    store.onCenterHub = { [weak self] in
      self?.centerOnActiveScreen()
    }
    store.onMinimizeHub = { [weak self] in
      self?.panel.miniaturize(nil)
    }
    store.onDetachBranch = { [weak self] offset in
      self?.detachBranch(offset: offset)
    }
    store.onCloseDetachedBranch = { [weak self] in
      self?.closeDetachedBranch()
    }
    store.onOpenChildDirectory = { [weak self] url in
      self?.openChildDirectory(url, parentID: nil)
    }
    store.onHubPinChange = { [weak self] isPinned in
      self?.panel.level = FolderHubWindowPinning.level(isPinned: isPinned)
    }

    panel.onEscape = { [weak store] in
      store?.handleEscape()
    }
    panel.onBack = { [weak store] in
      store?.navigateBack()
    }
    panel.onQuickLook = { [weak store] in
      store?.previewSelectedItem()
    }
    panel.onTrash = { [weak store] in
      store?.trashSelectedItem()
    }

    restorePosition()
    installGlobalMouseMonitor()
  }

  func show() {
    NSApp.unhide(nil)
    NSApp.activate(ignoringOtherApps: true)
    let animationBehavior = panel.animationBehavior
    panel.animationBehavior = .none
    panel.deminiaturize(nil)
    panel.orderFrontRegardless()
    panel.makeKeyAndOrderFront(nil)
    panel.animationBehavior = animationBehavior
  }

  func centerOnActiveScreen() {
    let screen =
      NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    guard let screen else { return }
    positionPanel(
      hubScreenPoint: CGPoint(
        x: screen.visibleFrame.midX,
        y: screen.visibleFrame.midY
      ),
      on: screen,
      animated: true
    )
    show()
  }

  func windowDidMove(_ notification: Notification) {
    guard !isUpdatingFrame, let screen = panel.screen else { return }
    let point = hubScreenPoint(for: metrics, in: panel.frame)
    let visible = screen.visibleFrame
    guard visible.width > 0, visible.height > 0 else { return }
    store.updatePanelLocation(
      SavedPanelLocation(
        displayIdentifier: screen.folderHubIdentifier,
        normalizedX: Double((point.x - visible.minX) / visible.width),
        normalizedY: Double((point.y - visible.minY) / visible.height)
      )
    )
  }

  private func configurePanel() {
    panel.title = "Folder Hub"
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isRestorable = false
    panel.isMovableByWindowBackground = false
    panel.becomesKeyOnlyIfNeeded = false
    panel.acceptsMouseMovedEvents = true
    panel.animationBehavior = .utilityWindow
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
    ]
    panel.level = FolderHubWindowPinning.level(
      isPinned: store.isHubPinned
    )
  }

  private func apply(
    metrics newMetrics: HubPresentationMetrics,
    animated _: Bool
  ) {
    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    guard let screen else { return }
    let currentHubPoint = hubScreenPoint(for: metrics, in: panel.frame)
    metrics = newMetrics
    positionPanel(
      hubScreenPoint: currentHubPoint,
      on: screen,
      animated: false
    )
  }

  private func positionPanel(
    hubScreenPoint: CGPoint,
    on screen: NSScreen,
    animated: Bool
  ) {
    let size = metrics.canvasSize
    var origin = CGPoint(
      x: hubScreenPoint.x - metrics.hubCenter.x,
      y: hubScreenPoint.y - size.height + metrics.hubCenter.y
    )
    let available = screen.visibleFrame.insetBy(dx: 10, dy: 10)
    origin.x = min(max(origin.x, available.minX), available.maxX - size.width)
    origin.y = min(max(origin.y, available.minY), available.maxY - size.height)
    let frame = CGRect(origin: origin, size: size)

    isUpdatingFrame = true
    panel.setFrame(frame, display: true, animate: animated)
    isUpdatingFrame = false
  }

  private func restorePosition() {
    let screen: NSScreen
    if let location = store.panelLocation,
      let matching = NSScreen.screens.first(where: {
        $0.folderHubIdentifier == location.displayIdentifier
      })
    {
      screen = matching
      let visible = matching.visibleFrame
      let point = CGPoint(
        x: visible.minX + CGFloat(location.normalizedX) * visible.width,
        y: visible.minY + CGFloat(location.normalizedY) * visible.height
      )
      positionPanel(hubScreenPoint: point, on: screen, animated: false)
    } else if let preferred = NSScreen.main ?? NSScreen.screens.first {
      screen = preferred
      positionPanel(
        hubScreenPoint: CGPoint(
          x: preferred.visibleFrame.midX,
          y: preferred.visibleFrame.midY
        ),
        on: preferred,
        animated: false
      )
    }
  }

  private func hubScreenPoint(
    for metrics: HubPresentationMetrics,
    in frame: CGRect
  ) -> CGPoint {
    CGPoint(
      x: frame.minX + metrics.hubCenter.x,
      y: frame.maxY - metrics.hubCenter.y
    )
  }

  private func detachBranch(offset: CGSize) {
    let currentHubPoint = hubScreenPoint(for: metrics, in: panel.frame)
    let branchCenter = HubPresentationMetrics.independentBranchCenter(
      hubCenter: currentHubPoint,
      hubSize: metrics.hubSize
    )
    let screenPoint = CGPoint(
      x: branchCenter.x + offset.width,
      y: branchCenter.y - offset.height
    )

    closeDetachedBranch()
    let controller = DetachedBranchPanelController(
      store: store
    ) { [weak store] in
      store?.collapse()
    }
    detachedBranchController = controller
    controller.show(centeredAt: screenPoint)
  }

  private func closeDetachedBranch() {
    detachedBranchController?.close()
    detachedBranchController = nil
  }

  private func openChildDirectory(_ url: URL, parentID: UUID?) {
    let parentFrame: CGRect
    if let parentID {
      guard let parentController = childDirectoryControllers[parentID] else {
        return
      }
      parentFrame = parentController.frame
    } else {
      guard let detachedBranchController else { return }
      parentFrame = detachedBranchController.frame
    }

    let registration = childDirectoryHierarchy.register(
      url,
      parentID: parentID
    )
    guard case .inserted(let node) = registration else {
      if case .existing(let node) = registration {
        childDirectoryControllers[node.id]?.bringToFront()
      }
      return
    }

    let controller = ChildDirectoryPanelController(
      directoryURL: node.directoryURL,
      onOpenDirectory: { [weak self] childURL in
        self?.openChildDirectory(childURL, parentID: node.id)
      },
      onClose: { [weak self] in
        self?.closeChildDirectory(node.id)
      }
    )
    let occupiedFrames = childDirectoryControllers.values.map(\.frame)
    childDirectoryControllers[node.id] = controller
    controller.show(
      adjacentTo: parentFrame,
      avoiding: occupiedFrames
    )
  }

  private func closeChildDirectory(_ id: UUID) {
    let removedNodes = childDirectoryHierarchy.removeSubtree(rootedAt: id)
    for node in removedNodes {
      childDirectoryControllers.removeValue(forKey: node.id)?.close()
    }
  }

  private func installGlobalMouseMonitor() {
    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.store.isExpanded else { return }
        guard !self.store.isBranchDetached else { return }
        let mouseLocation = NSEvent.mouseLocation
        let isInsideHub = self.panel.frame.contains(mouseLocation)
        let isInsideDetachedBubble =
          self.detachedBranchController?.frame.contains(mouseLocation)
          == true
        guard !isInsideHub, !isInsideDetachedBubble else { return }
        self.store.collapse()
      }
    }
  }

  deinit {
    if let globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
    }
  }
}

final class HubPanel: NSPanel {
  var onEscape: (() -> Void)?
  var onBack: (() -> Void)?
  var onQuickLook: (() -> Void)?
  var onTrash: (() -> Void)?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown || event.type == .rightMouseDown {
      NSApp.activate(ignoringOtherApps: true)
      makeKey()
    }
    super.sendEvent(event)
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 53:
      onEscape?()
    case 51:
      onBack?()
    case 49:
      onQuickLook?()
    case 117:
      onTrash?()
    default:
      super.keyDown(with: event)
    }
  }
}

extension NSScreen {
  var folderHubIdentifier: String {
    let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
    guard let number = deviceDescription[screenNumberKey] as? NSNumber else {
      return localizedName
    }
    let displayID = CGDirectDisplayID(number.uint32Value)
    guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
      return localizedName
    }
    let uuid = unmanagedUUID.takeRetainedValue()
    return CFUUIDCreateString(nil, uuid) as String
  }
}

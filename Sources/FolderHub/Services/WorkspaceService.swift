import AppKit
@preconcurrency import QuickLookUI

@MainActor
struct WorkspaceService {
  func open(_ url: URL) {
    NSWorkspace.shared.open(url)
  }

  func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func preview(_ url: URL) {
    QuickLookController.shared.preview(url)
  }
}

@MainActor
final class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource {
  static let shared = QuickLookController()
  private var itemURL: URL?

  func preview(_ url: URL) {
    itemURL = url
    guard let panel = QLPreviewPanel.shared() else { return }
    panel.dataSource = self
    panel.reloadData()
    panel.currentPreviewItemIndex = 0
    panel.level = .normal
    panel.collectionBehavior = [.fullScreenAuxiliary]
    panel.animationBehavior = .documentWindow
    if let screen =
      NSScreen.screens.first(where: {
        $0.visibleFrame.contains(NSEvent.mouseLocation)
      }) ?? NSScreen.main ?? NSScreen.screens.first
    {
      panel.setFrame(
        PreviewWindowLayout.frame(in: screen.visibleFrame),
        display: true,
        animate: panel.isVisible
      )
    }
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    itemURL == nil ? 0 : 1
  }

  func previewPanel(
    _ panel: QLPreviewPanel!,
    previewItemAt index: Int
  ) -> (any QLPreviewItem)! {
    itemURL as NSURL?
  }
}

enum PreviewWindowLayout {
  static func frame(in visibleFrame: CGRect) -> CGRect {
    let horizontalMargin: CGFloat = 64
    let verticalMargin: CGFloat = 54
    let width = min(
      max(720, visibleFrame.width * 0.58),
      max(320, visibleFrame.width - horizontalMargin * 2)
    )
    let height = min(
      max(520, visibleFrame.height * 0.68),
      max(260, visibleFrame.height - verticalMargin * 2)
    )
    return CGRect(
      x: visibleFrame.midX - width / 2,
      y: visibleFrame.midY - height / 2,
      width: width,
      height: height
    )
  }
}

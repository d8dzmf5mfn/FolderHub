import SwiftUI

struct HubRootView: View {
  @Bindable var store: HubStore
  @State private var isDropTargeted = false

  private var metrics: HubPresentationMetrics {
    store.presentationMetrics
  }

  var body: some View {
    ZStack {
      HubSurfaceView(
        store: store,
        isDropTargeted: $isDropTargeted,
        size: metrics.hubSize
      )
      .frame(
        width: metrics.hubSize.width,
        height: metrics.hubSize.height
      )
      .position(metrics.hubCenter)

      if let notice = store.notice {
        noticeView(notice)
          .position(
            x: metrics.hubCenter.x,
            y: metrics.hubCenter.y
              + metrics.hubSize.height / 2 + 8
          )
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
    .frame(width: metrics.canvasSize.width, height: metrics.canvasSize.height)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private func noticeView(_ notice: String) -> some View {
    if store.trashedItem != nil {
      Button {
        store.undoTrash()
      } label: {
        Text(notice)
          .font(.system(size: 10, weight: .medium))
          .lineLimit(1)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.primary)
      .accessibilityHint("Activates Undo")
    } else {
      Text(notice)
        .font(.system(size: 10, weight: .medium))
        .lineLimit(1)
        .foregroundStyle(.primary)
    }
  }
}

import SwiftUI
import UniformTypeIdentifiers

struct HubRootView: View {
  @Bindable var store: HubStore
  @State private var isDropTargeted = false
  @State private var blobProgress: CGFloat = 0
  @State private var settledBranchOffset: CGSize = .zero
  @State private var liveBranchTranslation: CGSize = .zero
  @State private var isBranchHovered = false
  @State private var isBranchPressed = false
  @Bindable private var glassAppearance = GlassAppearanceStore.shared

  private var glassOpticalOpacity: Double {
    glassAppearance.opticalOpacity
  }

  private var metrics: HubPresentationMetrics {
    store.presentationMetrics
  }

  private var branchOffset: CGSize {
    BranchDragPolicy.destination(
      settledOffset: settledBranchOffset,
      translation: liveBranchTranslation
    )
  }

  var body: some View {
    ZStack {
      hub

      if store.selectedFolderID != nil, !store.isBranchDetached {
        branch
      }

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
    .contentShape(
      HubBlobShape(
        metrics: metrics,
        hubSize: metrics.hubSize,
        progress: blobProgress,
        interactionOutset:
          HubPresentationMetrics.branchInteractionOutset,
        branchOffset: branchOffset
      )
    )
    .onChange(of: store.phase, initial: true) { _, phase in
      animateBlob(for: phase)
    }
    .onChange(of: store.selectedFolderID) { _, selectedFolderID in
      if selectedFolderID == nil {
        settledBranchOffset = .zero
      }
    }
  }

  private var hub: some View {
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
  }

  private var branch: some View {
    let baseCenter = metrics.branchCenter ?? metrics.hubCenter
    let finalCenter = CGPoint(
      x: baseCenter.x + branchOffset.width,
      y: baseCenter.y + branchOffset.height
    )
    let amount = min(max(blobProgress, 0), 1)

    return ZStack {
      bubbleShape
        .fill(.clear)
        .glassEffect(
          .clear.interactive(),
          in: bubbleShape
        )
        .opacity(glassOpticalOpacity)

      DraggableBranchHost(
        store: store,
        onChanged: updateBranchDrag,
        onEnded: finishBranchDrag,
        onHoverChanged: { isBranchHovered = $0 },
        onPressChanged: { isBranchPressed = $0 }
      )
    }
    .frame(
      width: metrics.branchVisualSize.width,
      height: metrics.branchVisualSize.height
    )
    .contentShape(bubbleShape)
    .overlay(alignment: .top) {
      BranchDragAffordance(
        isHovered: isBranchHovered,
        isPressed: isBranchPressed
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .overlay(alignment: .bottomTrailing) {
      BubbleResizeHandle(
        size: store.bubbleSize,
        onResize: store.resizeBubbles
      )
    }
    .scaleEffect(
      (0.72 + 0.28 * amount)
        * (isBranchPressed ? 0.985 : isBranchHovered ? 1.012 : 1)
    )
    .brightness(isBranchHovered ? 0.025 : 0)
    .opacity(amount)
    .position(finalCenter)
    .allowsHitTesting(store.phase == .expanded)
    .animation(
      .interactiveSpring(duration: 0.24, extraBounce: 0.2),
      value: isBranchHovered
    )
    .animation(
      .interactiveSpring(duration: 0.18, extraBounce: 0.16),
      value: isBranchPressed
    )
    .accessibilityHint("Click and drag this bubble away from the hub")
  }

  private var bubbleShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: HubPresentationMetrics.bubbleCornerRadius,
      style: .continuous
    )
  }

  private func updateBranchDrag(_ translation: CGSize) {
    liveBranchTranslation = translation
  }

  private func finishBranchDrag(_ translation: CGSize) {
    let destination = BranchDragPolicy.destination(
      settledOffset: settledBranchOffset,
      translation: translation
    )
    liveBranchTranslation = .zero
    if BranchDragPolicy.shouldDetach(destination) {
      settledBranchOffset = .zero
      store.detachSelectedBranch(offset: destination)
      return
    }
    withAnimation(
      .spring(duration: 0.48, bounce: 0.38, blendDuration: 0.08)
    ) {
      settledBranchOffset = destination
    }
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

  private func animateBlob(for phase: HubInteractionPhase) {
    switch phase {
    case .idle:
      blobProgress = 0
    case .selecting:
      settledBranchOffset = .zero
      blobProgress = 0
      withAnimation(
        .spring(duration: 0.56, bounce: 0.42, blendDuration: 0.08)
      ) {
        blobProgress = 1
      }
    case .expanded:
      withAnimation(.interactiveSpring(duration: 0.28, extraBounce: 0.18)) {
        blobProgress = 1
      }
    case .collapsing:
      withAnimation(.spring(duration: 0.34, bounce: 0.14)) {
        blobProgress = 0
      }
    }
  }
}

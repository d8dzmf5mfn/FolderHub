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
    BranchDragPolicy.clamped(
      CGSize(
        width:
          settledBranchOffset.width
          + liveBranchTranslation.width,
        height:
          settledBranchOffset.height
          + liveBranchTranslation.height
      )
    )
  }

  var body: some View {
    ZStack {
      HubBlobShape(
        metrics: metrics,
        hubDiameter: store.hubDiameter,
        progress: blobProgress,
        branchOffset: branchOffset
      )
      .fill(.clear)
      .glassEffect(
        .clear
          .tint(isDropTargeted ? Color.accentColor.opacity(0.1) : nil)
          .interactive(),
        in: HubBlobShape(
          metrics: metrics,
          hubDiameter: store.hubDiameter,
          progress: blobProgress,
          branchOffset: branchOffset
        )
      )
      .opacity(glassOpticalOpacity)

      hub

      if store.selectedFolderID != nil, !store.isBranchDetached {
        branch
      }

      if let notice = store.notice {
        noticeView(notice)
          .position(
            x: metrics.hubCenter.x,
            y: metrics.hubCenter.y
              + store.hubDiameter / 2 - 23
          )
          .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
    .frame(width: metrics.canvasSize.width, height: metrics.canvasSize.height)
    .contentShape(
      HubBlobShape(
        metrics: metrics,
        hubDiameter: store.hubDiameter,
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
      diameter: store.hubDiameter
    )
    .frame(
      width: store.hubDiameter,
      height: store.hubDiameter
    )
    .position(metrics.hubCenter)
  }

  private var branch: some View {
    let baseCenter = metrics.branchCenter ?? metrics.hubCenter
    let finalCenter = CGPoint(
      x: baseCenter.x + branchOffset.width,
      y: baseCenter.y + branchOffset.height
    )
    let direction = CGVector(
      dx: finalCenter.x - metrics.hubCenter.x,
      dy: finalCenter.y - metrics.hubCenter.y
    ).normalized(or: CGVector(dx: 1, dy: 0))
    let hubRadius = store.hubDiameter / 2
    let origin = CGPoint(
      x: metrics.hubCenter.x + direction.dx * (hubRadius - 12),
      y: metrics.hubCenter.y + direction.dy * (hubRadius - 12)
    )
    let amount = min(max(blobProgress, 0), 1)
    let center = CGPoint(
      x: origin.x + (finalCenter.x - origin.x) * amount,
      y: origin.y + (finalCenter.y - origin.y) * amount
    )

    return DraggableBranchHost(
      store: store,
      onChanged: updateBranchDrag,
      onEnded: finishBranchDrag,
      onHoverChanged: { isBranchHovered = $0 },
      onPressChanged: { isBranchPressed = $0 }
    )
    .frame(
      width: HubPresentationMetrics.branchSize.width,
      height: HubPresentationMetrics.branchSize.height
    )
    .contentShape(Rectangle())
    .overlay(alignment: .top) {
      BranchDragAffordance(
        isHovered: isBranchHovered,
        isPressed: isBranchPressed
      )
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
    .scaleEffect(
      (0.72 + 0.28 * amount)
        * (isBranchPressed ? 0.985 : isBranchHovered ? 1.012 : 1)
    )
    .brightness(isBranchHovered ? 0.025 : 0)
    .opacity(amount)
    .position(center)
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

  private func updateBranchDrag(_ translation: CGSize) {
    liveBranchTranslation = BranchDragPolicy.resisted(translation)
  }

  private func finishBranchDrag(_ translation: CGSize) {
    let resisted = BranchDragPolicy.resisted(translation)
    let destination = BranchDragPolicy.clamped(
      CGSize(
        width: settledBranchOffset.width + resisted.width,
        height: settledBranchOffset.height + resisted.height
      )
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

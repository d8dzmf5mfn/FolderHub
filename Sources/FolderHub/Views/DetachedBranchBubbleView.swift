import SwiftUI

struct DetachedBranchBubbleView: View {
  @Bindable var store: HubStore
  let onReturnToHub: () -> Void
  let onDragChanged: (CGSize) -> Void
  let onDragEnded: (CGSize) -> Void

  @State private var isHovered = false
  @State private var isPressed = false
  @Bindable private var glassAppearance = GlassAppearanceStore.shared

  private var glassOpticalOpacity: Double {
    glassAppearance.opticalOpacity
  }

  var body: some View {
    ZStack {
      bubbleShape
        .fill(.clear)
        .glassEffect(
          .clear.interactive(),
          in: bubbleShape
        )
        .opacity(glassOpticalOpacity)

      DraggableBranchHost(
        store: store,
        onChanged: onDragChanged,
        onEnded: onDragEnded,
        onHoverChanged: { isHovered = $0 },
        onPressChanged: { isPressed = $0 },
        tracksMovingWindow: true
      )
      .frame(
        width: HubPresentationMetrics.branchSize.width,
        height: HubPresentationMetrics.branchSize.height
      )

      VStack {
        BranchDragAffordance(
          isHovered: isHovered,
          isPressed: isPressed
        )
        .padding(.top, HubPresentationMetrics.branchInteractionOutset)
        .accessibilityHidden(true)
        Spacer()
      }
      .allowsHitTesting(false)
    }
    .frame(width: bubbleSize.width, height: bubbleSize.height)
    .contentShape(bubbleShape)
    .scaleEffect(isPressed ? 0.985 : isHovered ? 1.012 : 1)
    .brightness(isHovered ? 0.025 : 0)
    .animation(
      .interactiveSpring(duration: 0.24, extraBounce: 0.2),
      value: isHovered
    )
    .animation(
      .interactiveSpring(duration: 0.18, extraBounce: 0.16),
      value: isPressed
    )
    .allowsWindowActivationEvents(true)
    .contextMenu {
      Button("Return to Hub") {
        onReturnToHub()
      }
    }
    .accessibilityLabel("Detached folder bubble")
  }

  private var bubbleSize: CGSize {
    let outset = HubPresentationMetrics.branchInteractionOutset
    return CGSize(
      width: HubPresentationMetrics.branchSize.width + outset * 2,
      height: HubPresentationMetrics.branchSize.height + outset * 2
    )
  }

  private var bubbleShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 48, style: .continuous)
  }

}

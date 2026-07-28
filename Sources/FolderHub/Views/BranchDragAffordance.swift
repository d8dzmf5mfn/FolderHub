import SwiftUI

enum DragCollisionMetrics {
  static let hubHitDiameter: CGFloat = 32
  static let hubDotDiameter: CGFloat = 7
  static let branchHitSize = CGSize(width: 56, height: 28)
  static let listContentSpacing: CGFloat = 5
  static let folderRowHitHeight: CGFloat = 22

  static var branchContentTopInset: CGFloat {
    branchHitSize.height + listContentSpacing
  }

  static func branchHitRect(in bounds: CGRect) -> CGRect {
    CGRect(
      x: bounds.midX - branchHitSize.width / 2,
      y: bounds.maxY - branchHitSize.height,
      width: branchHitSize.width,
      height: branchHitSize.height
    )
  }
}

struct HubDragCollisionHandle: View {
  @State private var isHovered = false

  var body: some View {
    Circle()
      .fill(
        Color.primary.opacity(
          isHovered ? 0.24 : 0.14
        )
      )
      .frame(
        width:
          isHovered
          ? DragCollisionMetrics.hubDotDiameter * 1.24
          : DragCollisionMetrics.hubDotDiameter,
        height:
          isHovered
          ? DragCollisionMetrics.hubDotDiameter * 1.24
          : DragCollisionMetrics.hubDotDiameter
      )
      .shadow(
        color: Color.white.opacity(isHovered ? 0.32 : 0.12),
        radius: 3
      )
      .frame(
        width: DragCollisionMetrics.hubHitDiameter,
        height: DragCollisionMetrics.hubHitDiameter
      )
      .contentShape(Circle())
      .overlay {
        WindowDragHitBox()
          .clipShape(Circle())
      }
      .onHover { isHovered = $0 }
      .animation(
        .interactiveSpring(duration: 0.2, extraBounce: 0.24),
        value: isHovered
      )
      .allowsWindowActivationEvents(true)
      .accessibilityElement()
      .accessibilityLabel("Move Folder Hub")
      .accessibilityHint("Drag to move Folder Hub")
  }
}

struct BranchDragAffordance: View {
  let isHovered: Bool
  let isPressed: Bool

  var body: some View {
    Capsule(style: .continuous)
      .fill(
        Color.primary.opacity(
          isPressed ? 0.34 : isHovered ? 0.24 : 0.12
        )
      )
      .frame(width: isPressed ? 34 : 28, height: 4)
      .shadow(
        color: Color.white.opacity(isHovered ? 0.34 : 0.12),
        radius: 3,
        y: -1
      )
      .animation(
        .interactiveSpring(duration: 0.22, extraBounce: 0.28),
        value: isHovered
      )
      .animation(
        .interactiveSpring(duration: 0.18, extraBounce: 0.2),
        value: isPressed
      )
      .frame(
        width: DragCollisionMetrics.branchHitSize.width,
        height: DragCollisionMetrics.branchHitSize.height
      )
      .contentShape(Rectangle())
  }
}

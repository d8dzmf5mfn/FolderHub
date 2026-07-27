import AppKit

enum FolderHubWindowPinning {
  static func level(isPinned: Bool) -> NSWindow.Level {
    isPinned ? .floating : .normal
  }
}

enum HubWindowControls {
  static let hubHitDiameter: CGFloat = 32
  static let childHitDiameter: CGFloat = 28
  static let zIndex = 20.0
  static let idleOpacity = 0.62
  static let labelSeparation: CGFloat = 8
  static let centerPanelStyleMask: NSWindow.StyleMask = [
    .borderless,
    .miniaturizable,
  ]

  static func hubPinCenter(diameter: CGFloat) -> CGPoint {
    hubControlCenter(diameter: diameter, horizontalDirection: 1)
  }

  static func hubMinimizeCenter(diameter: CGFloat) -> CGPoint {
    hubControlCenter(diameter: diameter, horizontalDirection: -1)
  }

  static func labelExclusionRects(diameter: CGFloat) -> [CGRect] {
    let hubCenter = CGPoint(x: diameter / 2, y: diameter / 2)
    let side =
      hubHitDiameter + labelSeparation * 2
    return [
      hubMinimizeCenter(diameter: diameter),
      hubPinCenter(diameter: diameter),
    ].map { center in
      CGRect(
        x: center.x - hubCenter.x - side / 2,
        y: center.y - hubCenter.y - side / 2,
        width: side,
        height: side
      )
    }
  }

  static func separatingLabelFromControls(
    _ proposedCenter: CGPoint,
    size: CGSize,
    diameter: CGFloat
  ) -> CGPoint {
    var center = proposedCenter
    for exclusion in labelExclusionRects(diameter: diameter) {
      let labelRect = CGRect(
        x: center.x - size.width / 2,
        y: center.y - size.height / 2,
        width: size.width,
        height: size.height
      )
      guard labelRect.intersects(exclusion) else { continue }
      center.y =
        exclusion.maxY + size.height / 2 + labelSeparation
    }
    return center
  }

  private static func hubControlCenter(
    diameter: CGFloat,
    horizontalDirection: CGFloat
  ) -> CGPoint {
    let radius = max(
      0,
      diameter / 2 - hubHitDiameter / 2 - 4
    )
    let diagonalOffset = radius / sqrt(2)
    return CGPoint(
      x: diameter / 2 + horizontalDirection * diagonalOffset,
      y: diameter / 2 - diagonalOffset
    )
  }
}

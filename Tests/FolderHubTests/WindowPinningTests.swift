import AppKit
import Testing

@testable import FolderHub

@Suite("Window pinning")
struct WindowPinningTests {
  @Test("Pinned windows use the floating level")
  func pinnedLevel() {
    #expect(
      FolderHubWindowPinning.level(isPinned: true) == .floating
    )
  }

  @Test("Unpinned windows return to the normal level")
  func normalLevel() {
    #expect(
      FolderHubWindowPinning.level(isPinned: false) == .normal
    )
  }

  @Test("Window controls use explicit nonzero interaction values")
  func interactionValues() {
    #expect(HubWindowControls.hubHitDiameter == 32)
    #expect(HubWindowControls.childHitDiameter == 28)
    #expect(HubWindowControls.zIndex > 0)
    #expect(HubWindowControls.idleOpacity > 0)
    #expect(
      HubWindowControls.centerPanelStyleMask.contains(.miniaturizable)
    )
  }

  @Test("Hub controls stay distinct and inside the circular hit shape")
  func hubControlCenters() {
    let diameter: CGFloat = 112
    let centers = [
      HubWindowControls.hubPinCenter(diameter: diameter),
      HubWindowControls.hubMinimizeCenter(diameter: diameter),
    ]

    #expect(centers[0] != centers[1])
    for center in centers {
      let distance = hypot(
        center.x - diameter / 2,
        center.y - diameter / 2
      )
      #expect(
        distance + HubWindowControls.hubHitDiameter / 2
          < diameter / 2
      )
    }
  }

  @Test("Selected labels are pushed outside control isolation zones")
  func selectedLabelSeparation() {
    let diameter: CGFloat = 152
    let minimizeCenter = HubWindowControls.hubMinimizeCenter(
      diameter: diameter
    )
    let proposed = CGPoint(
      x: minimizeCenter.x - diameter / 2,
      y: minimizeCenter.y - diameter / 2
    )
    let size = CGSize(width: 44, height: 16)
    let adjusted = HubWindowControls.separatingLabelFromControls(
      proposed,
      size: size,
      diameter: diameter
    )
    let adjustedRect = CGRect(
      x: adjusted.x - size.width / 2,
      y: adjusted.y - size.height / 2,
      width: size.width,
      height: size.height
    )

    #expect(adjusted != proposed)
    #expect(
      HubWindowControls.labelExclusionRects(diameter: diameter)
        .allSatisfy { !$0.intersects(adjustedRect) }
    )
  }
}

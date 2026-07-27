import Foundation
import Testing

@testable import FolderHub

@Suite("Hub label layout")
struct HubLayoutEngineTests {
  @Test("Layout is deterministic and remains inside the orb")
  func deterministicAndContained() {
    let folders = (0..<12).map {
      makeFolderRecord(
        name: "Folder\($0)",
        id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", $0 + 1))")!,
        seed: UInt64($0 + 100)
      )
    }
    let engine = HubLayoutEngine()

    for count in 1...folders.count {
      let subset = Array(folders.prefix(count))
      let first = engine.layout(folders: subset)
      let second = engine.layout(folders: subset)
      let diameter = engine.recommendedHubDiameter(folders: subset)
      let innerRadius =
        diameter / 2 - HubSizingPolicy.contentInset

      #expect(first == second)
      #expect(first.labels.count == subset.count)

      for label in first.labels.values {
        let halfWidth = label.estimatedSize.width / 2
        let halfHeight = label.estimatedSize.height / 2
        let corners = [
          CGPoint(
            x: label.centerOffset.x - halfWidth,
            y: label.centerOffset.y - halfHeight
          ),
          CGPoint(
            x: label.centerOffset.x + halfWidth,
            y: label.centerOffset.y - halfHeight
          ),
          CGPoint(
            x: label.centerOffset.x - halfWidth,
            y: label.centerOffset.y + halfHeight
          ),
          CGPoint(
            x: label.centerOffset.x + halfWidth,
            y: label.centerOffset.y + halfHeight
          ),
        ]
        #expect(
          corners.allSatisfy {
            $0.magnitude <= innerRadius + 0.01
          }
        )
      }

      let labels = Array(first.labels.values)
      let controlRects = HubWindowControls.labelExclusionRects(
        diameter: diameter
      )
      for leftIndex in labels.indices {
        #expect(
          controlRects.allSatisfy {
            !$0.intersects(labels[leftIndex].collisionRect)
          }
        )
        for rightIndex in labels.indices where rightIndex > leftIndex {
          #expect(
            !labels[leftIndex].collisionRect.intersects(
              labels[rightIndex].collisionRect
            ),
            "Label overlap at folder count \(count)"
          )
        }
      }
    }
  }

  @Test("Adding a folder preserves existing positions as a soft constraint")
  func incrementalLayoutStability() {
    let original = (0..<6).map {
      makeFolderRecord(name: "Item\($0)", seed: UInt64($0 + 10))
    }
    let engine = HubLayoutEngine()
    let before = engine.layout(folders: original)
    let after = engine.layout(
      folders: original + [makeFolderRecord(name: "New", seed: 999)],
      previous: before
    )

    let totalMovement = original.reduce(CGFloat.zero) { total, folder in
      guard let old = before.labels[folder.id]?.centerOffset,
        let new = after.labels[folder.id]?.centerOffset
      else {
        return total
      }
      return total + hypot(new.x - old.x, new.y - old.y)
    }

    #expect(totalMovement < 140)
  }

  @Test("Hub diameter tightly follows label occupancy")
  func contentFittedDiameter() {
    let shortNames = [
      makeFolderRecord(name: "A", seed: 1),
      makeFolderRecord(name: "B", seed: 2),
    ]
    let longNames = [
      makeFolderRecord(name: "LongFolderNameAlpha", seed: 3),
      makeFolderRecord(name: "LongFolderNameBeta", seed: 4),
    ]
    let crowded = (0..<12).map {
      makeFolderRecord(
        name: "FolderWithLongName\($0)",
        seed: UInt64($0 + 20)
      )
    }
    let engine = HubLayoutEngine()
    let shortDiameter = engine.recommendedHubDiameter(
      folders: shortNames
    )
    let longDiameter = engine.recommendedHubDiameter(
      folders: longNames
    )
    let crowdedDiameter = engine.recommendedHubDiameter(
      folders: crowded
    )

    #expect(shortDiameter == 124)
    #expect(longDiameter > shortDiameter)
    #expect(crowdedDiameter >= longDiameter)
    #expect(crowdedDiameter <= HubSizingPolicy.maximumDiameter)
  }
}

extension CGPoint {
  fileprivate var magnitude: CGFloat {
    hypot(x, y)
  }
}

extension HubLabelLayout {
  fileprivate var collisionRect: CGRect {
    CGRect(
      x: centerOffset.x - estimatedSize.width / 2,
      y: centerOffset.y - estimatedSize.height / 2,
      width: estimatedSize.width,
      height: estimatedSize.height
    )
    .insetBy(dx: -1, dy: -1)
  }
}

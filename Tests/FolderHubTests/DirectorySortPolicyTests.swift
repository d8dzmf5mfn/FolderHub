import Foundation
import Testing

@testable import FolderHub

@Suite("Directory sorting")
struct DirectorySortPolicyTests {
  @Test("Default order preserves folders first and names ascending")
  func defaultOrder() {
    let items = [
      item("Zulu.md", size: 8),
      item("Beta", isDirectory: true),
      item("Alpha.md", size: 2),
      item("Alpha", isDirectory: true),
    ]

    let sorted = DirectorySortPolicy.sorted(items, using: .default)

    #expect(sorted.map(\.name) == ["Alpha", "Beta", "Alpha.md", "Zulu.md"])
  }

  @Test("Names can sort descending within each item group")
  func nameDescending() {
    let order = DirectorySortOrder(
      criterion: .name,
      direction: .descending
    )
    let items = [
      item("Alpha.md"),
      item("Alpha", isDirectory: true),
      item("Zulu.md"),
      item("Zulu", isDirectory: true),
    ]

    let sorted = DirectorySortPolicy.sorted(items, using: order)

    #expect(sorted.map(\.name) == ["Zulu", "Alpha", "Zulu.md", "Alpha.md"])
  }

  @Test("Modification dates support both directions and keep unknown dates last")
  func modificationDate() {
    let items = [
      item("Unknown"),
      item("Newest", modifiedAt: Date(timeIntervalSince1970: 30)),
      item("Oldest", modifiedAt: Date(timeIntervalSince1970: 10)),
    ]
    let newestFirst = DirectorySortPolicy.sorted(
      items,
      using: DirectorySortOrder(
        criterion: .modificationDate,
        direction: .descending
      )
    )
    let oldestFirst = DirectorySortPolicy.sorted(
      items,
      using: DirectorySortOrder(
        criterion: .modificationDate,
        direction: .ascending
      )
    )

    #expect(newestFirst.map(\.name) == ["Newest", "Oldest", "Unknown"])
    #expect(oldestFirst.map(\.name) == ["Oldest", "Newest", "Unknown"])
  }

  @Test("File sizes support both directions and keep unavailable sizes last")
  func size() {
    let items = [
      item("Unknown"),
      item("Large", size: 300),
      item("Small", size: 10),
    ]
    let largestFirst = DirectorySortPolicy.sorted(
      items,
      using: DirectorySortOrder(
        criterion: .size,
        direction: .descending
      )
    )
    let smallestFirst = DirectorySortPolicy.sorted(
      items,
      using: DirectorySortOrder(
        criterion: .size,
        direction: .ascending
      )
    )

    #expect(largestFirst.map(\.name) == ["Large", "Small", "Unknown"])
    #expect(smallestFirst.map(\.name) == ["Small", "Large", "Unknown"])
  }

  @Test("Folders remain before files for every criterion")
  func foldersRemainFirst() {
    let items = [
      item(
        "Large File",
        modifiedAt: Date(timeIntervalSince1970: 40),
        size: 400
      ),
      item(
        "Old Folder",
        isDirectory: true,
        modifiedAt: Date(timeIntervalSince1970: 10)
      ),
    ]

    for criterion in DirectorySortCriterion.allCases {
      let sorted = DirectorySortPolicy.sorted(
        items,
        using: .defaultOrder(for: criterion)
      )
      #expect(sorted.first?.isNavigableDirectory == true)
    }
  }

  @Test("Folder metadata sizes sort within the folder group")
  func folderSizes() {
    let items = [
      item("Small Folder", isDirectory: true, size: 64),
      item("Large Folder", isDirectory: true, size: 288),
      item("File", size: 1_024),
    ]

    let sorted = DirectorySortPolicy.sorted(
      items,
      using: .defaultOrder(for: .size)
    )

    #expect(
      sorted.map(\.name)
        == ["Large Folder", "Small Folder", "File"]
    )
  }

  private func item(
    _ name: String,
    isDirectory: Bool = false,
    modifiedAt: Date? = nil,
    size: Int64? = nil
  ) -> DirectoryItem {
    DirectoryItem(
      url: URL(fileURLWithPath: "/tmp/\(name)"),
      name: name,
      isDirectory: isDirectory,
      isPackage: false,
      isSymbolicLink: false,
      isHidden: false,
      modifiedAt: modifiedAt,
      byteSize: size,
      visibleChildCount: isDirectory ? 0 : nil
    )
  }
}

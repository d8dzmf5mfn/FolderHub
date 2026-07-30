import Foundation

enum DirectorySortCriterion: String, CaseIterable, Identifiable, Sendable {
  case name
  case modificationDate
  case size

  var id: Self { self }

  var title: String {
    switch self {
    case .name:
      "Name"
    case .modificationDate:
      "Date Modified"
    case .size:
      "Size"
    }
  }

  var systemImage: String {
    switch self {
    case .name:
      "textformat"
    case .modificationDate:
      "calendar"
    case .size:
      "internaldrive"
    }
  }

  var defaultDirection: DirectorySortDirection {
    switch self {
    case .name:
      .ascending
    case .modificationDate, .size:
      .descending
    }
  }

  var ascendingTitle: String {
    switch self {
    case .name:
      "A to Z"
    case .modificationDate:
      "Oldest First"
    case .size:
      "Smallest First"
    }
  }

  var descendingTitle: String {
    switch self {
    case .name:
      "Z to A"
    case .modificationDate:
      "Newest First"
    case .size:
      "Largest First"
    }
  }
}

enum DirectorySortDirection: String, CaseIterable, Identifiable, Sendable {
  case ascending
  case descending

  var id: Self { self }
}

struct DirectorySortOrder: Equatable, Sendable {
  let criterion: DirectorySortCriterion
  let direction: DirectorySortDirection

  static let `default` = DirectorySortOrder(
    criterion: .name,
    direction: .ascending
  )

  static func defaultOrder(
    for criterion: DirectorySortCriterion
  ) -> DirectorySortOrder {
    DirectorySortOrder(
      criterion: criterion,
      direction: criterion.defaultDirection
    )
  }
}

enum DirectorySortPolicy {
  static func sorted(
    _ items: [DirectoryItem],
    using order: DirectorySortOrder
  ) -> [DirectoryItem] {
    items.sorted { left, right in
      if left.isNavigableDirectory != right.isNavigableDirectory {
        return left.isNavigableDirectory
      }

      let ordered: Bool?
      switch order.criterion {
      case .name:
        ordered = comparison(
          left.name.localizedStandardCompare(right.name),
          direction: order.direction
        )
      case .modificationDate:
        ordered = comparison(
          left.modifiedAt,
          right.modifiedAt,
          direction: order.direction
        )
      case .size:
        ordered = comparison(
          left.byteSize,
          right.byteSize,
          direction: order.direction
        )
      }

      if let ordered {
        return ordered
      }

      let nameComparison = left.name.localizedStandardCompare(right.name)
      if nameComparison != .orderedSame {
        return nameComparison == .orderedAscending
      }
      return left.url.path < right.url.path
    }
  }

  private static func comparison(
    _ result: ComparisonResult,
    direction: DirectorySortDirection
  ) -> Bool? {
    guard result != .orderedSame else { return nil }
    switch direction {
    case .ascending:
      return result == .orderedAscending
    case .descending:
      return result == .orderedDescending
    }
  }

  private static func comparison<Value: Comparable>(
    _ left: Value?,
    _ right: Value?,
    direction: DirectorySortDirection
  ) -> Bool? {
    switch (left, right) {
    case (.none, .none):
      return nil
    case (.some, .none):
      return true
    case (.none, .some):
      return false
    case (.some(let left), .some(let right)):
      guard left != right else { return nil }
      switch direction {
      case .ascending:
        return left < right
      case .descending:
        return left > right
      }
    }
  }
}

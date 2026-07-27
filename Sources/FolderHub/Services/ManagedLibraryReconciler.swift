import Foundation

struct ManagedLibraryReconciliation: Sendable {
  let folders: [ManagedFolderRecord]
  let addedCount: Int
  let removedIDs: Set<UUID>
}

struct ManagedLibraryReconciler: Sendable {
  let rootURL: URL

  func reconcile(
    existing: [ManagedFolderRecord],
    discovered: [ManagedFolderRecord],
    maximumCount: Int
  ) -> ManagedLibraryReconciliation {
    var unmatchedDiscovered = discovered
    var reconciled: [ManagedFolderRecord] = []
    var removedIDs: Set<UUID> = []

    for record in existing {
      if let matchIndex = unmatchedDiscovered.firstIndex(
        where: { matches(record, $0) }
      ) {
        let match = unmatchedDiscovered.remove(at: matchIndex)
        reconciled.append(refreshing(record, from: match))
      } else if isManagedRecord(record) {
        removedIDs.insert(record.id)
      } else {
        reconciled.append(record)
      }
    }

    let availableSlots = max(0, maximumCount - reconciled.count)
    let additions = unmatchedDiscovered.prefix(availableSlots)
    reconciled.append(contentsOf: additions)

    return ManagedLibraryReconciliation(
      folders: reconciled,
      addedCount: additions.count,
      removedIDs: removedIDs
    )
  }

  func affectsMembership(eventPaths: [String]) -> Bool {
    let rootPath = normalized(rootURL).path
    return eventPaths.contains { path in
      let eventURL = URL(fileURLWithPath: path).standardizedFileURL
      if normalized(eventURL).path == rootPath {
        return true
      }
      return normalized(eventURL.deletingLastPathComponent()).path == rootPath
    }
  }

  private func isManagedRecord(_ record: ManagedFolderRecord) -> Bool {
    let parentURL = URL(fileURLWithPath: record.lastKnownPath)
      .standardizedFileURL
      .deletingLastPathComponent()
    return normalized(parentURL).path == normalized(rootURL).path
  }

  private func matches(
    _ existing: ManagedFolderRecord,
    _ discovered: ManagedFolderRecord
  ) -> Bool {
    if existing.resourceIdentifier == discovered.resourceIdentifier {
      return true
    }
    return normalized(URL(fileURLWithPath: existing.lastKnownPath)).path
      == normalized(URL(fileURLWithPath: discovered.lastKnownPath)).path
  }

  private func refreshing(
    _ existing: ManagedFolderRecord,
    from discovered: ManagedFolderRecord
  ) -> ManagedFolderRecord {
    let pathChanged =
      normalized(URL(fileURLWithPath: existing.lastKnownPath)).path
      != normalized(URL(fileURLWithPath: discovered.lastKnownPath)).path
    guard
      existing.displayName != discovered.displayName
        || existing.resourceIdentifier != discovered.resourceIdentifier
        || pathChanged
    else {
      return existing
    }

    return ManagedFolderRecord(
      id: existing.id,
      displayName: discovered.displayName,
      bookmarkData: discovered.bookmarkData,
      bookmarkIsSecurityScoped: discovered.bookmarkIsSecurityScoped,
      resourceIdentifier: discovered.resourceIdentifier,
      lastKnownPath: discovered.lastKnownPath,
      layoutSeed: existing.layoutSeed
    )
  }

  private func normalized(_ url: URL) -> URL {
    url.standardizedFileURL.resolvingSymlinksInPath()
  }
}

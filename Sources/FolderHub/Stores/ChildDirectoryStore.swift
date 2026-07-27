import Foundation
import Observation

@Observable
@MainActor
final class ChildDirectoryStore {
  let directoryURL: URL
  private(set) var items: [DirectoryItem] = []
  private(set) var selectedItemID: URL?
  private(set) var isLoading = true
  private(set) var errorMessage: String?
  private(set) var isPinned = false

  @ObservationIgnored private let directoryService = DirectoryService()
  @ObservationIgnored private let workspace = WorkspaceService()
  @ObservationIgnored private let watcher = FSEventWatcher()
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var watcherDebounceTask: Task<Void, Never>?

  @ObservationIgnored var onOpenDirectory: ((URL) -> Void)?
  @ObservationIgnored var onClose: (() -> Void)?
  @ObservationIgnored var onPinChange: ((Bool) -> Void)?

  init(directoryURL: URL) {
    self.directoryURL = directoryURL
    refresh()
    startWatcher()
  }

  var title: String {
    directoryURL.lastPathComponent
  }

  var selectedItem: DirectoryItem? {
    guard let selectedItemID else { return nil }
    return items.first { $0.id == selectedItemID }
  }

  func activate(_ item: DirectoryItem) {
    selectedItemID = item.id
    if item.isNavigableDirectory {
      onOpenDirectory?(item.url)
    } else {
      workspace.preview(item.url)
    }
  }

  func open(_ item: DirectoryItem) {
    selectedItemID = item.id
    if item.isNavigableDirectory {
      onOpenDirectory?(item.url)
    } else {
      workspace.open(item.url)
    }
  }

  func preview(_ item: DirectoryItem) {
    selectedItemID = item.id
    workspace.preview(item.url)
  }

  func previewSelectedItem() {
    guard let selectedItem else { return }
    workspace.preview(selectedItem.url)
  }

  func reveal(_ item: DirectoryItem) {
    workspace.reveal(item.url)
  }

  func revealDirectory() {
    workspace.reveal(directoryURL)
  }

  func close() {
    onClose?()
  }

  func togglePinned() {
    isPinned.toggle()
    onPinChange?(isPinned)
  }

  func refresh() {
    refreshTask?.cancel()
    isLoading = true
    errorMessage = nil
    let directoryURL = directoryURL
    let service = directoryService

    refreshTask = Task { [weak self] in
      let result = await Task.detached {
        Result {
          try service.contents(
            of: directoryURL,
            showHiddenFiles: false
          )
        }
      }.value
      guard !Task.isCancelled, let self else { return }
      self.isLoading = false
      switch result {
      case .success(let items):
        self.items = items
        if let selectedItemID = self.selectedItemID,
          !items.contains(where: { $0.id == selectedItemID })
        {
          self.selectedItemID = nil
        }
      case .failure(let error):
        self.items = []
        self.errorMessage = error.localizedDescription
      }
    }
  }

  private func startWatcher() {
    watcher.start(watching: directoryURL) { [weak self] in
      DispatchQueue.main.async {
        self?.watcherDebounceTask?.cancel()
        self?.watcherDebounceTask = Task { [weak self] in
          try? await Task.sleep(for: .milliseconds(150))
          guard !Task.isCancelled else { return }
          self?.refresh()
        }
      }
    }
  }
}

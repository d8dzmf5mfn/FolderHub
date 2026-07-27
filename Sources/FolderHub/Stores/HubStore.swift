import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
@MainActor
final class HubStore {
  static let shared = HubStore()
  static let maximumFolderCount = 12

  private(set) var folders: [ManagedFolderRecord]
  private(set) var layout: HubLayoutSnapshot
  private(set) var phase: HubInteractionPhase = .idle
  private(set) var selectedFolderID: UUID?
  private(set) var isBranchDetached = false
  private(set) var branchDirection = CGVector(dx: 1, dy: -0.25)
  private(set) var directoryItems: [DirectoryItem] = []
  private(set) var selectedItemID: URL?
  private(set) var navigationPath: [URL] = []
  private(set) var isLoadingDirectory = false
  private(set) var panelLocation: SavedPanelLocation?
  private(set) var notice: String?
  private(set) var trashedItem: TrashedItem?
  private(set) var isLaunchAtLoginEnabled = false
  private(set) var isHubPinned: Bool
  private(set) var renameItemID: URL?
  var renameDraft = ""
  var showHiddenFiles: Bool {
    didSet {
      UserDefaults.standard.set(showHiddenFiles, forKey: Self.showHiddenKey)
      refreshDirectory()
    }
  }

  @ObservationIgnored private let bookmarkStore = BookmarkStore()
  @ObservationIgnored private let persistence = HubPersistence()
  @ObservationIgnored private let layoutEngine = HubLayoutEngine()
  @ObservationIgnored private let directoryService = DirectoryService()
  @ObservationIgnored private let fileOperations = FileOperationService()
  @ObservationIgnored private let managedLibrary = ManagedLibraryService()
  @ObservationIgnored private let workspace = WorkspaceService()
  @ObservationIgnored private let watcher = FSEventWatcher()
  @ObservationIgnored private let libraryWatcher = FSEventWatcher()
  @ObservationIgnored private let launchAtLogin = LaunchAtLoginService()
  @ObservationIgnored private var activeSecurityScopedURL: URL?
  @ObservationIgnored private var activeSecurityScopeStarted = false
  @ObservationIgnored private var selectionTask: Task<Void, Never>?
  @ObservationIgnored private var collapseTask: Task<Void, Never>?
  @ObservationIgnored private var refreshTask: Task<Void, Never>?
  @ObservationIgnored private var watcherDebounceTask: Task<Void, Never>?
  @ObservationIgnored private var libraryWatcherDebounceTask: Task<Void, Never>?
  @ObservationIgnored private var librarySyncTask: Task<Void, Never>?
  @ObservationIgnored private var noticeTask: Task<Void, Never>?
  @ObservationIgnored private var undoExpiryTask: Task<Void, Never>?

  @ObservationIgnored var onPresentationMetricsChange: ((HubPresentationMetrics, Bool) -> Void)?
  @ObservationIgnored var onShowHub: (() -> Void)?
  @ObservationIgnored var onCenterHub: (() -> Void)?
  @ObservationIgnored var onMinimizeHub: (() -> Void)?
  @ObservationIgnored var onDetachBranch: ((CGSize) -> Void)?
  @ObservationIgnored var onCloseDetachedBranch: (() -> Void)?
  @ObservationIgnored var onOpenChildDirectory: ((URL) -> Void)?
  @ObservationIgnored var onHubPinChange: ((Bool) -> Void)?

  private static let showHiddenKey = "FolderHub.showHiddenFiles"
  private static let hubPinnedKey = "FolderHub.isHubPinned"

  private init() {
    let persisted = persistence.load()
    let loadedFolders = Array(
      persisted.folders.prefix(Self.maximumFolderCount)
    )
    folders = loadedFolders
    panelLocation = persisted.panelLocation
    showHiddenFiles = UserDefaults.standard.bool(forKey: Self.showHiddenKey)
    isHubPinned = UserDefaults.standard.bool(forKey: Self.hubPinnedKey)
    let initialLayoutEngine = HubLayoutEngine()
    let initialHubDiameter = initialLayoutEngine.recommendedHubDiameter(
      folders: loadedFolders
    )
    layout = initialLayoutEngine.layout(
      folders: loadedFolders,
      hubDiameter: initialHubDiameter
    )
    isLaunchAtLoginEnabled = launchAtLogin.isEnabled
  }

  var selectedFolder: ManagedFolderRecord? {
    guard let selectedFolderID else { return nil }
    return folders.first { $0.id == selectedFolderID }
  }

  var hubDiameter: CGFloat {
    layoutEngine.recommendedHubDiameter(folders: folders)
  }

  var currentDirectory: URL? {
    navigationPath.last
  }

  var selectedItem: DirectoryItem? {
    guard let selectedItemID else { return nil }
    return directoryItems.first { $0.id == selectedItemID }
  }

  var isExpanded: Bool {
    selectedFolderID != nil
  }

  var presentationMetrics: HubPresentationMetrics {
    selectedFolderID == nil || isBranchDetached
      ? .collapsed(hubDiameter: hubDiameter)
      : .expanded(
        hubDiameter: hubDiameter,
        direction: branchDirection
      )
  }

  func chooseAndAddFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.prompt = "Add to Folder Hub"
    guard panel.runModal() == .OK else { return }
    addFolders(panel.urls)
  }

  func addFolders(_ urls: [URL]) {
    Task { [weak self] in
      await self?.importFolders(urls)
    }
  }

  func addDroppedItems(_ urls: [URL]) {
    Task { [weak self] in
      await self?.importDroppedItems(urls)
    }
  }

  func synchronizeManagedLibrary() {
    librarySyncTask?.cancel()
    librarySyncTask = Task { [weak self] in
      guard let self else { return }
      do {
        try await self.managedLibrary.ensureLibraryExists()
        guard !Task.isCancelled else { return }
        self.startManagedLibraryWatcher()
        await self.reconcileManagedLibrary()
      } catch {
        guard !Task.isCancelled else { return }
        self.showNotice(
          "Couldn’t monitor FolderHubLibrary: \(error.localizedDescription)",
          duration: .seconds(8)
        )
      }
    }
  }

  func moveFolderBackToDesktop(_ id: UUID) {
    guard let record = folders.first(where: { $0.id == id }) else { return }

    Task {
      do {
        let resolved = try bookmarkStore.resolve(record)
        defer {
          if resolved.didStartSecurityScope {
            resolved.url.stopAccessingSecurityScopedResource()
          }
        }
        let destination = try await managedLibrary.moveToDesktop(resolved.url)
        if selectedFolderID == id {
          collapse()
        }
        folders.removeAll { $0.id == id }
        layout = layoutEngine.layout(
          folders: folders,
          previous: layout,
          hubDiameter: hubDiameter
        )
        notifyPresentationMetricsChanged()
        persist()
        showNotice("Moved back to Desktop.")
        workspace.reveal(destination)
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func revealManagedLibrary() {
    Task {
      do {
        try await managedLibrary.ensureLibraryExists()
        workspace.open(managedLibrary.rootURL)
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  private func importFolders(_ urls: [URL]) async {
    var changed = false
    var importedCount = 0
    var failures: [String] = []
    let importer = ManagedFolderImportTransaction(
      bookmarkStore: bookmarkStore,
      managedLibrary: managedLibrary,
      persistence: persistence
    )

    for url in urls {
      guard folders.count < Self.maximumFolderCount else {
        failures.append("Folder Hub holds up to 12 folders.")
        break
      }

      do {
        let sourceRecord = try bookmarkStore.makeRecord(for: url)
        let isDuplicate = folders.contains {
          $0.resourceIdentifier == sourceRecord.resourceIdentifier
            || URL(fileURLWithPath: $0.lastKnownPath)
              .standardizedFileURL == url.standardizedFileURL
        }
        guard !isDuplicate else {
          failures.append("\(url.lastPathComponent) is already in the Hub.")
          continue
        }

        let record = try await importer.importFolder(
          url,
          existingFolders: folders,
          panelLocation: panelLocation
        )
        folders.append(record)
        changed = true
        importedCount += 1
      } catch {
        failures.append(
          "\(url.lastPathComponent): \(error.localizedDescription)"
        )
      }
    }

    if changed {
      updateFolderLayout()
    }

    if let failure = failures.first {
      let prefix = importedCount > 0 ? "Added \(importedCount). " : ""
      showNotice(prefix + failure, duration: .seconds(8))
    } else if importedCount > 0 {
      showNotice(
        importedCount == 1
          ? "Moved into FolderHubLibrary."
          : "Moved \(importedCount) folders into FolderHubLibrary."
      )
    }
  }

  private func reconcileManagedLibrary() async {
    do {
      let managedURLs = try await managedLibrary.managedFolderURLs()
      guard !Task.isCancelled else { return }

      var discoveredRecords: [ManagedFolderRecord] = []
      var firstFailure: String?

      for url in managedURLs {
        do {
          let record = try bookmarkStore.makeRecord(for: url)
          discoveredRecords.append(record)
        } catch {
          firstFailure =
            firstFailure
            ?? "\(url.lastPathComponent): \(error.localizedDescription)"
        }
      }

      guard !Task.isCancelled else { return }
      let reconciliation = ManagedLibraryReconciler(
        rootURL: managedLibrary.rootURL
      ).reconcile(
        existing: folders,
        discovered: discoveredRecords,
        maximumCount: Self.maximumFolderCount
      )
      if reconciliation.folders != folders {
        try saveState(folders: reconciliation.folders)
        clearSelectionIfRemoved(reconciliation.removedIDs)
        folders = reconciliation.folders
        updateFolderLayout()
      }

      if let firstFailure {
        showNotice(firstFailure, duration: .seconds(8))
      } else if reconciliation.addedCount > 0
        && !reconciliation.removedIDs.isEmpty
      {
        showNotice("Synced FolderHubLibrary.")
      } else if reconciliation.addedCount > 0 {
        showNotice(
          reconciliation.addedCount == 1
            ? "Recovered 1 folder from FolderHubLibrary."
            : "Recovered \(reconciliation.addedCount) folders from FolderHubLibrary."
        )
      } else if !reconciliation.removedIDs.isEmpty {
        showNotice(
          reconciliation.removedIDs.count == 1
            ? "Removed 1 folder that left FolderHubLibrary."
            : "Removed \(reconciliation.removedIDs.count) folders that left FolderHubLibrary."
        )
      }
    } catch {
      guard !Task.isCancelled else { return }
      showNotice(
        "Couldn’t sync FolderHubLibrary: \(error.localizedDescription)",
        duration: .seconds(8)
      )
    }
  }

  private func updateFolderLayout() {
    layout = layoutEngine.layout(
      folders: folders,
      previous: layout,
      hubDiameter: hubDiameter
    )
    notifyPresentationMetricsChanged()
  }

  private func importDroppedItems(_ urls: [URL]) async {
    var folderURLs: [URL] = []
    var fileURLs: [URL] = []

    for url in urls {
      do {
        let values = try url.resourceValues(
          forKeys: [.isDirectoryKey]
        )
        if values.isDirectory == true {
          folderURLs.append(url)
        } else {
          fileURLs.append(url)
        }
      } catch {
        showNotice(error.localizedDescription)
      }
    }

    if !folderURLs.isEmpty {
      await importFolders(folderURLs)
    }
    if !fileURLs.isEmpty {
      await importFilesToInbox(fileURLs)
    }
  }

  private func importFilesToInbox(_ urls: [URL]) async {
    let inboxURL = managedLibrary.inboxURL.standardizedFileURL
    var inboxRecordExists = folders.contains {
      URL(fileURLWithPath: $0.lastKnownPath).standardizedFileURL
        == inboxURL
    }

    if !inboxRecordExists {
      guard folders.count < Self.maximumFolderCount else {
        showNotice("Folder Hub needs one free slot for Inbox.")
        return
      }

      do {
        try await managedLibrary.ensureInboxExists()
        inboxRecordExists = folders.contains {
          URL(fileURLWithPath: $0.lastKnownPath).standardizedFileURL
            == inboxURL
        }
        if !inboxRecordExists {
          let inboxRecord = try bookmarkStore.makeRecord(for: inboxURL)
          folders.append(inboxRecord)
          layout = layoutEngine.layout(
            folders: folders,
            previous: layout,
            hubDiameter: hubDiameter
          )
          notifyPresentationMetricsChanged()
          persist()
        }
      } catch {
        showNotice(error.localizedDescription)
        return
      }
    }

    var importedCount = 0
    for url in urls {
      do {
        _ = try await managedLibrary.importFileToInbox(url)
        importedCount += 1
      } catch {
        showNotice(error.localizedDescription)
      }
    }

    guard importedCount > 0 else { return }
    showNotice(
      importedCount == 1
        ? "Moved file into Inbox."
        : "Moved \(importedCount) files into Inbox."
    )
  }

  func removeFolder(_ id: UUID) {
    if selectedFolderID == id {
      collapse()
    }
    folders.removeAll { $0.id == id }
    layout = layoutEngine.layout(
      folders: folders,
      previous: layout,
      hubDiameter: hubDiameter
    )
    notifyPresentationMetricsChanged()
    persist()
  }

  func selectFolder(_ id: UUID) {
    if selectedFolderID == id {
      collapse()
      return
    }

    if isBranchDetached {
      isBranchDetached = false
      onCloseDetachedBranch?()
    }

    guard let recordIndex = folders.firstIndex(where: { $0.id == id }),
      let label = layout.labels[id]
    else {
      return
    }

    selectionTask?.cancel()
    collapseTask?.cancel()
    deactivateSecurityScope()
    watcher.stop()
    navigationPath = []
    directoryItems = []
    selectedItemID = nil
    selectedFolderID = id
    phase = .selecting

    let vector = CGVector(
      dx: label.centerOffset.x,
      dy: label.centerOffset.y
    )
    branchDirection = vector.normalized(
      or: fallbackDirection(for: folders[recordIndex])
    )
    onPresentationMetricsChange?(
      .expanded(
        hubDiameter: hubDiameter,
        direction: branchDirection
      ),
      true
    )

    do {
      let resolved = try bookmarkStore.resolve(folders[recordIndex])
      activeSecurityScopedURL = resolved.url
      activeSecurityScopeStarted = resolved.didStartSecurityScope
      navigationPath = [resolved.url]

      if resolved.isStale {
        folders[recordIndex] = try bookmarkStore.refresh(
          folders[recordIndex],
          resolvedURL: resolved.url
        )
        persist()
      }
      refreshDirectory()
    } catch {
      showNotice(error.localizedDescription)
      collapse()
      return
    }

    selectionTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(180))
      guard !Task.isCancelled, let self, self.selectedFolderID == id else {
        return
      }
      self.phase = .expanded
      self.startWatcher()
    }
  }

  func collapse() {
    guard selectedFolderID != nil else { return }
    selectionTask?.cancel()
    collapseTask?.cancel()
    refreshTask?.cancel()
    watcherDebounceTask?.cancel()
    watcher.stop()
    renameItemID = nil
    deactivateSecurityScope()

    if isBranchDetached {
      isBranchDetached = false
      onCloseDetachedBranch?()
      phase = .idle
      selectedFolderID = nil
      navigationPath = []
      directoryItems = []
      selectedItemID = nil
      onPresentationMetricsChange?(
        .collapsed(hubDiameter: hubDiameter),
        true
      )
      return
    }

    phase = .collapsing

    collapseTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(360))
      guard !Task.isCancelled, let self else { return }
      self.phase = .idle
      self.selectedFolderID = nil
      self.navigationPath = []
      self.directoryItems = []
      self.selectedItemID = nil
      self.onPresentationMetricsChange?(
        .collapsed(hubDiameter: self.hubDiameter),
        true
      )
    }
  }

  func detachSelectedBranch(offset: CGSize) {
    guard selectedFolderID != nil, !isBranchDetached else { return }
    isBranchDetached = true
    phase = .idle
    onDetachBranch?(offset)
    onPresentationMetricsChange?(
      .collapsed(hubDiameter: hubDiameter),
      false
    )
  }

  private func notifyPresentationMetricsChanged() {
    onPresentationMetricsChange?(presentationMetrics, true)
  }

  func enterDirectory(_ item: DirectoryItem) {
    guard item.isNavigableDirectory else { return }
    navigationPath.append(item.url)
    directoryItems = []
    selectedItemID = nil
    refreshDirectory()
    startWatcher()
  }

  func navigateBack() {
    guard navigationPath.count > 1 else {
      collapse()
      return
    }
    navigationPath.removeLast()
    directoryItems = []
    selectedItemID = nil
    refreshDirectory()
    startWatcher()
  }

  func handleEscape() {
    if navigationPath.count > 1 {
      navigateBack()
    } else {
      collapse()
    }
  }

  func open(_ item: DirectoryItem) {
    if item.isNavigableDirectory {
      onOpenChildDirectory?(item.url)
    } else {
      workspace.open(item.url)
    }
  }

  func selectItem(_ item: DirectoryItem) {
    selectedItemID = item.id
  }

  func activateItem(_ item: DirectoryItem) {
    selectItem(item)
    if item.isNavigableDirectory {
      onOpenChildDirectory?(item.url)
    } else {
      preview(item)
    }
  }

  func previewSelectedItem() {
    guard let selectedItem else { return }
    preview(selectedItem)
  }

  func trashSelectedItem() {
    guard let selectedItem else { return }
    trash(selectedItem)
  }

  func preview(_ item: DirectoryItem) {
    workspace.preview(item.url)
  }

  func reveal(_ item: DirectoryItem) {
    workspace.reveal(item.url)
  }

  func revealSelectedFolder() {
    guard let url = activeSecurityScopedURL else { return }
    workspace.reveal(url)
  }

  func beginRename(_ item: DirectoryItem) {
    renameItemID = item.id
    renameDraft = item.name
  }

  func cancelRename() {
    renameItemID = nil
    renameDraft = ""
  }

  func commitRename(_ item: DirectoryItem) {
    let proposedName = renameDraft
    renameItemID = nil
    renameDraft = ""
    Task {
      do {
        _ = try await fileOperations.rename(item, to: proposedName)
        refreshDirectory()
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func createFolder() {
    guard let currentDirectory else { return }
    let alert = NSAlert()
    alert.messageText = "New Folder"
    alert.informativeText = "Enter a name for the new folder."
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")
    let field = NSTextField(
      frame: NSRect(x: 0, y: 0, width: 260, height: 24)
    )
    field.placeholderString = "Untitled Folder"
    alert.accessoryView = field
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    let name = field.stringValue.isEmpty ? "Untitled Folder" : field.stringValue

    Task {
      do {
        _ = try await fileOperations.createFolder(
          named: name,
          in: currentDirectory
        )
        refreshDirectory()
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func move(_ item: DirectoryItem) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.prompt = "Move Here"
    guard panel.runModal() == .OK, let destination = panel.url else { return }

    Task {
      do {
        var resolution: FileConflictResolution = .cancel
        let expectedDestination = destination.appendingPathComponent(item.name)
        if FileManager.default.fileExists(atPath: expectedDestination.path) {
          resolution = conflictResolution(for: expectedDestination)
        }
        _ = try await fileOperations.move(
          item.url,
          to: destination,
          conflictResolution: resolution
        )
        refreshDirectory()
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func moveDroppedItems(_ urls: [URL], to destination: DirectoryItem) {
    guard destination.isNavigableDirectory else { return }
    Task {
      for url in urls {
        do {
          _ = try await fileOperations.move(
            url,
            to: destination.url,
            conflictResolution: .keepBoth
          )
        } catch {
          showNotice(error.localizedDescription)
        }
      }
      refreshDirectory()
    }
  }

  func trash(_ item: DirectoryItem) {
    Task { [self] in
      do {
        trashedItem = try await fileOperations.trash(item)
        showNotice("Moved to Trash · Undo", duration: .seconds(8))
        undoExpiryTask?.cancel()
        undoExpiryTask = Task { [weak self] in
          try? await Task.sleep(for: .seconds(8))
          guard !Task.isCancelled else { return }
          self?.trashedItem = nil
        }
        refreshDirectory()
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func undoTrash() {
    guard let trashedItem else { return }
    undoExpiryTask?.cancel()
    Task {
      do {
        try await fileOperations.restore(trashedItem)
        self.trashedItem = nil
        notice = nil
        refreshDirectory()
      } catch {
        showNotice(error.localizedDescription)
      }
    }
  }

  func toggleShowHiddenFiles() {
    showHiddenFiles.toggle()
  }

  func setLaunchAtLogin(_ isEnabled: Bool) {
    do {
      try launchAtLogin.setEnabled(isEnabled)
      isLaunchAtLoginEnabled = launchAtLogin.isEnabled
    } catch {
      isLaunchAtLoginEnabled = launchAtLogin.isEnabled
      showNotice(error.localizedDescription)
    }
  }

  func updatePanelLocation(_ location: SavedPanelLocation) {
    panelLocation = location
    persist()
  }

  func showHub() {
    onShowHub?()
  }

  func centerHub() {
    onCenterHub?()
  }

  func minimizeHub() {
    onMinimizeHub?()
  }

  func setHubPinned(_ isPinned: Bool) {
    guard isHubPinned != isPinned else { return }
    isHubPinned = isPinned
    UserDefaults.standard.set(isPinned, forKey: Self.hubPinnedKey)
    onHubPinChange?(isPinned)
  }

  func toggleHubPinned() {
    setHubPinned(!isHubPinned)
  }

  func clearAllFolders() {
    collapse()
    folders = []
    layout = .empty
    persist()
  }

  private func refreshDirectory() {
    refreshTask?.cancel()
    guard let directory = currentDirectory else { return }
    isLoadingDirectory = true
    let showHiddenFiles = showHiddenFiles
    let service = directoryService

    refreshTask = Task { [weak self] in
      let result = await Task.detached {
        Result {
          try service.contents(
            of: directory,
            showHiddenFiles: showHiddenFiles
          )
        }
      }.value
      guard !Task.isCancelled, let self,
        self.currentDirectory == directory
      else {
        return
      }
      self.isLoadingDirectory = false
      switch result {
      case .success(let items):
        self.directoryItems = items
        if let selectedItemID = self.selectedItemID,
          !items.contains(where: { $0.id == selectedItemID })
        {
          self.selectedItemID = nil
        }
      case .failure(let error):
        self.directoryItems = []
        self.showNotice(error.localizedDescription)
      }
    }
  }

  private func startWatcher() {
    guard let currentDirectory else { return }
    watcher.start(watching: currentDirectory) { [weak self] in
      DispatchQueue.main.async {
        self?.watcherDebounceTask?.cancel()
        self?.watcherDebounceTask = Task { [weak self] in
          try? await Task.sleep(for: .milliseconds(150))
          guard !Task.isCancelled else { return }
          self?.refreshDirectory()
        }
      }
    }
  }

  private func startManagedLibraryWatcher() {
    let rootURL = managedLibrary.rootURL
    let reconciler = ManagedLibraryReconciler(rootURL: rootURL)
    libraryWatcher.start(
      watching: rootURL,
      onEvents: { [weak self] eventPaths in
        guard reconciler.affectsMembership(eventPaths: eventPaths) else {
          return
        }

        DispatchQueue.main.async {
          self?.libraryWatcherDebounceTask?.cancel()
          self?.libraryWatcherDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            self?.synchronizeManagedLibrary()
          }
        }
      }
    )
  }

  private func clearSelectionIfRemoved(_ removedIDs: Set<UUID>) {
    guard let selectedFolderID, removedIDs.contains(selectedFolderID) else {
      return
    }

    selectionTask?.cancel()
    collapseTask?.cancel()
    refreshTask?.cancel()
    watcherDebounceTask?.cancel()
    watcher.stop()
    deactivateSecurityScope()

    if isBranchDetached {
      isBranchDetached = false
      onCloseDetachedBranch?()
    }
    phase = .idle
    self.selectedFolderID = nil
    navigationPath = []
    directoryItems = []
    selectedItemID = nil
    renameItemID = nil
  }

  private func deactivateSecurityScope() {
    if activeSecurityScopeStarted {
      activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
    }
    activeSecurityScopedURL = nil
    activeSecurityScopeStarted = false
  }

  private func fallbackDirection(for record: ManagedFolderRecord) -> CGVector {
    let angle = Double(record.layoutSeed % 6_283) / 1_000
    return CGVector(dx: cos(angle), dy: sin(angle))
  }

  private func conflictResolution(for destination: URL)
    -> FileConflictResolution
  {
    let alert = NSAlert()
    alert.messageText = "“\(destination.lastPathComponent)” already exists."
    alert.informativeText = "Choose how Folder Hub should resolve the conflict."
    alert.addButton(withTitle: "Keep Both")
    alert.addButton(withTitle: "Replace")
    alert.addButton(withTitle: "Cancel")
    switch alert.runModal() {
    case .alertFirstButtonReturn:
      return .keepBoth
    case .alertSecondButtonReturn:
      return .replace
    default:
      return .cancel
    }
  }

  private func persist() {
    do {
      try saveState(folders: folders)
    } catch {
      showNotice("Couldn’t save Folder Hub state.")
    }
  }

  private func saveState(folders: [ManagedFolderRecord]) throws {
    try persistence.save(
      PersistedHubState(
        folders: folders,
        panelLocation: panelLocation
      )
    )
  }

  private func showNotice(
    _ message: String,
    duration: Duration = .seconds(3)
  ) {
    noticeTask?.cancel()
    notice = message
    noticeTask = Task { [weak self] in
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      self?.notice = nil
    }
  }
}

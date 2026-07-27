import SwiftUI
import UniformTypeIdentifiers

struct BranchView: View {
  @Bindable var store: HubStore

  var body: some View {
    ZStack {
      if store.isLoadingDirectory, store.directoryItems.isEmpty {
        ProgressView()
          .controlSize(.small)
      } else if store.directoryItems.isEmpty {
        Text("Empty")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      } else {
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(store.directoryItems) { item in
              BranchRowView(store: store, item: item)
            }
          }
          .padding(.horizontal, 15)
          .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .contentShape(
          .interaction,
          Rectangle().inset(
            by: -HubPresentationMetrics.branchInteractionOutset
          )
        )
        .mask(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0),
              .init(color: .black, location: 0.09),
              .init(color: .black, location: 0.91),
              .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(
      .interaction,
      Rectangle().inset(
        by: -HubPresentationMetrics.branchInteractionOutset
      )
    )
    .allowsWindowActivationEvents(true)
    .contextMenu {
      Button("New Folder") {
        store.createFolder()
      }
      Divider()
      Button("Show Current Folder in Finder") {
        if let currentDirectory = store.currentDirectory {
          store.reveal(
            DirectoryItem(
              url: currentDirectory,
              name: currentDirectory.lastPathComponent,
              isDirectory: true,
              isPackage: false,
              isSymbolicLink: false,
              isHidden: false,
              modifiedAt: nil
            )
          )
        }
      }
    }
    .accessibilityLabel("Folder contents")
  }
}

private struct BranchRowView: View {
  @Bindable var store: HubStore
  let item: DirectoryItem
  @State private var isDropTargeted = false

  private var isSelected: Bool {
    store.selectedItemID == item.id
  }

  var body: some View {
    Group {
      if store.renameItemID == item.id {
        TextField("Name", text: $store.renameDraft)
          .textFieldStyle(.plain)
          .font(.system(size: 12, weight: .medium))
          .onSubmit {
            store.commitRename(item)
          }
          .onExitCommand {
            store.cancelRename()
          }
      } else {
        Button {
          store.activateItem(item)
        } label: {
          Text(item.name)
            .font(
              .system(
                size: 12,
                weight: isSelected ? .semibold : .regular
              )
            )
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
          TapGesture(count: 2).onEnded {
            store.open(item)
          }
        )
      }
    }
    .frame(height: 20)
    .padding(.horizontal, 3)
    .background(
      Capsule()
        .fill(
          isDropTargeted
            ? Color.accentColor.opacity(0.16)
            : Color.clear
        )
    )
    .onDrop(
      of: [UTType.fileURL.identifier],
      isTargeted: $isDropTargeted
    ) { providers in
      guard item.isNavigableDirectory else { return false }
      loadDroppedURLs(providers) { urls in
        store.moveDroppedItems(urls, to: item)
      }
      return true
    }
    .contextMenu {
      Button(item.isNavigableDirectory ? "Open Here" : "Open") {
        store.open(item)
      }
      Button("Quick Look") {
        store.preview(item)
      }
      Button("Show in Finder") {
        store.reveal(item)
      }
      Divider()
      Button("Rename") {
        store.beginRename(item)
      }
      Button("Move To…") {
        store.move(item)
      }
      Button("Move to Trash", role: .destructive) {
        store.trash(item)
      }
    }
    .accessibilityLabel(item.name)
    .accessibilityValue(item.isNavigableDirectory ? "Folder" : "File")
  }

  private func loadDroppedURLs(
    _ providers: [NSItemProvider],
    completion: @escaping ([URL]) -> Void
  ) {
    let group = DispatchGroup()
    let lock = NSLock()
    var urls: [URL] = []

    for provider in providers {
      group.enter()
      provider.loadItem(
        forTypeIdentifier: UTType.fileURL.identifier,
        options: nil
      ) { item, _ in
        defer { group.leave() }
        let url: URL?
        if let data = item as? Data {
          url = URL(dataRepresentation: data, relativeTo: nil)
        } else if let value = item as? URL {
          url = value
        } else if let value = item as? NSURL {
          url = value as URL
        } else {
          url = nil
        }
        if let url {
          lock.lock()
          urls.append(url)
          lock.unlock()
        }
      }
    }

    group.notify(queue: .main) {
      completion(urls)
    }
  }
}

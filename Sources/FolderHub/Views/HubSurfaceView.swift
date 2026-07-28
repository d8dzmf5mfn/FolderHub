import SwiftUI
import UniformTypeIdentifiers

struct HubSurfaceView: View {
  @Bindable var store: HubStore
  @Binding var isDropTargeted: Bool
  let size: CGSize

  @State private var isHovered = false
  @State private var isDragHandleHovered = false
  @Bindable private var glassAppearance = GlassAppearanceStore.shared

  private var glassOpticalOpacity: Double {
    glassAppearance.opticalOpacity
  }

  var body: some View {
    ZStack {
      bubbleShape
        .fill(.clear)
        .glassEffect(
          .clear
            .tint(isDropTargeted ? Color.accentColor.opacity(0.1) : nil)
            .interactive(),
          in: bubbleShape
        )
        .opacity(glassOpticalOpacity)

      VStack(spacing: 0) {
        dragHeader
        contents
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .frame(width: size.width, height: size.height)
    .contentShape(bubbleShape)
    .scaleEffect(isHovered ? 1.008 : 1)
    .brightness(isHovered ? 0.02 : 0)
    .animation(
      .interactiveSpring(duration: 0.24, extraBounce: 0.18),
      value: isHovered
    )
    .onHover { isHovered = $0 }
    .onDrop(
      of: [UTType.fileURL.identifier],
      isTargeted: $isDropTargeted,
      perform: acceptDrop
    )
    .allowsWindowActivationEvents(true)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Folder Hub")
  }

  private var dragHeader: some View {
    ZStack {
      HStack {
        Text("Folder Hub")
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(Color.primary.opacity(0.5))
          .lineLimit(1)

        Spacer(minLength: 0)

        hubPinButton
        hubMinimizeButton
      }

      BranchDragAffordance(
        isHovered: isDragHandleHovered,
        isPressed: false
      )
      .overlay {
        WindowDragHitBox()
      }
      .onHover { isDragHandleHovered = $0 }
      .accessibilityElement()
      .accessibilityLabel("Move Folder Hub")
      .accessibilityHint("Drag to move Folder Hub")
    }
    .frame(height: DragCollisionMetrics.branchHitSize.height)
  }

  @ViewBuilder
  private var contents: some View {
    if store.folders.isEmpty {
      Button {
        store.chooseAndAddFolder()
      } label: {
        VStack(spacing: 3) {
          Text("Drop or click to add")
            .font(.system(size: 11, weight: .medium))
          Text("Up to \(HubStore.maximumFolderCount) folders")
            .font(.system(size: 9.5))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    } else {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(store.folders) { folder in
            folderRow(folder)
          }
        }
        .padding(.vertical, 5)
      }
      .scrollIndicators(.hidden)
      .scrollBounceBehavior(.basedOnSize)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.08),
            .init(color: .black, location: 0.92),
            .init(color: .clear, location: 1),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
  }

  private var hubPinButton: some View {
    Button {
      store.toggleHubPinned()
    } label: {
      Image(systemName: store.isHubPinned ? "pin.fill" : "pin")
        .font(.system(size: 8.5, weight: .bold))
        .foregroundStyle(
          store.isHubPinned
            ? Color.accentColor.opacity(0.72)
            : Color.primary.opacity(0.42)
        )
        .frame(
          width: HubWindowControls.childHitDiameter,
          height: HubWindowControls.childHitDiameter
        )
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .background(
      Circle()
        .fill(
          store.isHubPinned
            ? Color.accentColor.opacity(0.08)
            : Color.primary.opacity(isHovered ? 0.07 : 0.035)
        )
    )
    .frame(
      width: HubWindowControls.childHitDiameter,
      height: HubWindowControls.childHitDiameter
    )
    .contentShape(Circle())
    .zIndex(HubWindowControls.zIndex)
    .allowsHitTesting(true)
    .allowsWindowActivationEvents(true)
    .help(store.isHubPinned ? "Unpin Folder Hub" : "Keep Folder Hub on top")
    .accessibilityLabel(
      store.isHubPinned ? "Unpin Folder Hub" : "Pin Folder Hub"
    )
    .accessibilityValue(store.isHubPinned ? "On top" : "Normal level")
  }

  private var hubMinimizeButton: some View {
    Button {
      store.minimizeHub()
    } label: {
      Image(systemName: "minus")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Color.primary.opacity(0.42))
        .frame(
          width: HubWindowControls.childHitDiameter,
          height: HubWindowControls.childHitDiameter
        )
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .background(
      Circle()
        .fill(Color.primary.opacity(isHovered ? 0.07 : 0.035))
    )
    .frame(
      width: HubWindowControls.childHitDiameter,
      height: HubWindowControls.childHitDiameter
    )
    .contentShape(Circle())
    .zIndex(HubWindowControls.zIndex)
    .allowsHitTesting(true)
    .allowsWindowActivationEvents(true)
    .help("Minimize Folder Hub")
    .accessibilityLabel("Minimize Folder Hub")
    .accessibilityHint("Child folder bubbles stay open")
  }

  private func folderRow(_ folder: ManagedFolderRecord) -> some View {
    let isSelected =
      store.selectedFolderID == folder.id
      && !store.isBranchDetached

    return Button {
      store.selectFolder(folder.id)
    } label: {
      Text(folder.displayName)
        .font(
          .system(
            size: 12,
            weight: isSelected ? .semibold : .regular
          )
        )
        .foregroundStyle(
          isSelected
            ? Color.accentColor.opacity(0.78)
            : Color.primary.opacity(0.64)
        )
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .padding(.horizontal, 3)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      Capsule()
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.08)
            : Color.clear
        )
    )
    .contextMenu {
      Button("Show in Finder") {
        if store.selectedFolderID != folder.id {
          store.selectFolder(folder.id)
        }
        store.revealSelectedFolder()
      }
      Divider()
      Button("Move Back to Desktop") {
        store.moveFolderBackToDesktop(folder.id)
      }
      Button("Remove Reference", role: .destructive) {
        store.removeFolder(folder.id)
      }
    }
    .accessibilityLabel(folder.displayName)
    .accessibilityHint("Opens the folder inside Folder Hub")
  }

  private var bubbleShape: RoundedRectangle {
    RoundedRectangle(
      cornerRadius: HubPresentationMetrics.bubbleCornerRadius,
      style: .continuous
    )
  }

  private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
    var accepted = false
    for provider in providers
    where provider.hasItemConformingToTypeIdentifier(
      UTType.fileURL.identifier
    ) {
      accepted = true
      provider.loadItem(
        forTypeIdentifier: UTType.fileURL.identifier,
        options: nil
      ) { item, _ in
        let url: URL?
        if let data = item as? Data {
          url = URL(dataRepresentation: data, relativeTo: nil)
        } else if let itemURL = item as? URL {
          url = itemURL
        } else if let itemURL = item as? NSURL {
          url = itemURL as URL
        } else {
          url = nil
        }
        guard let url else { return }
        Task { @MainActor in
          store.addDroppedItems([url])
        }
      }
    }
    return accepted
  }
}

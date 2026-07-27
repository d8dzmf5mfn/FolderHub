import SwiftUI
import UniformTypeIdentifiers

struct HubSurfaceView: View {
  @Bindable var store: HubStore
  @Binding var isDropTargeted: Bool
  let diameter: CGFloat

  @State private var isHovered = false

  var body: some View {
    ZStack {
      Circle()
        .fill(.clear)
        .contentShape(Circle())
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)

      if store.folders.isEmpty {
        Button {
          store.chooseAndAddFolder()
        } label: {
          VStack(spacing: 3) {
            Text("Folder Hub")
              .font(.system(size: 14, weight: .semibold))
            Text("Drop or click to add")
              .font(.system(size: 10.5))
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(HubElasticButtonStyle())
      } else {
        ForEach(store.folders) { folder in
          if let label = store.layout.labels[folder.id] {
            folderLabel(folder, layout: label)
          }
        }
      }

      HubDragCollisionHandle()
        .position(x: diameter / 2, y: diameter / 2)

      hubMinimizeButton
        .position(HubWindowControls.hubMinimizeCenter(diameter: diameter))
        .zIndex(HubWindowControls.zIndex)

      hubPinButton
        .position(HubWindowControls.hubPinCenter(diameter: diameter))
        .zIndex(HubWindowControls.zIndex)
    }
    .frame(width: diameter, height: diameter)
    .contentShape(Circle())
    .onHover { isHovered = $0 }
    .onDrop(
      of: [UTType.fileURL.identifier],
      isTargeted: $isDropTargeted,
      perform: acceptDrop
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Folder Hub")
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
            : Color.primary.opacity(0.4)
        )
        .frame(
          width: HubWindowControls.hubHitDiameter,
          height: HubWindowControls.hubHitDiameter
        )
        .contentShape(Circle())
    }
    .buttonStyle(HubElasticButtonStyle())
    .background(
      Circle()
        .fill(
          store.isHubPinned
            ? Color.accentColor.opacity(0.08)
            : Color.primary.opacity(isHovered ? 0.055 : 0.025)
        )
    )
    .frame(
      width: HubWindowControls.hubHitDiameter,
      height: HubWindowControls.hubHitDiameter
    )
    .contentShape(Circle())
    .opacity(
      isHovered || store.isHubPinned
        ? 1 : HubWindowControls.idleOpacity
    )
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
          width: HubWindowControls.hubHitDiameter,
          height: HubWindowControls.hubHitDiameter
        )
        .contentShape(Circle())
    }
    .buttonStyle(HubElasticButtonStyle())
    .background(
      Circle()
        .fill(Color.primary.opacity(isHovered ? 0.055 : 0.025))
    )
    .frame(
      width: HubWindowControls.hubHitDiameter,
      height: HubWindowControls.hubHitDiameter
    )
    .contentShape(Circle())
    .opacity(isHovered ? 1 : HubWindowControls.idleOpacity)
    .allowsHitTesting(true)
    .allowsWindowActivationEvents(true)
    .help("Minimize Folder Hub")
    .accessibilityLabel("Minimize Folder Hub")
    .accessibilityHint("Child folder bubbles stay open")
  }

  private func folderLabel(
    _ folder: ManagedFolderRecord,
    layout: HubLabelLayout
  ) -> some View {
    let isSelected =
      store.selectedFolderID == folder.id
      && !store.isBranchDetached
    let offset = displayedOffset(for: layout, selected: isSelected)

    return Button {
      store.selectFolder(folder.id)
    } label: {
      Text(folder.displayName)
        .font(
          .system(
            size: isSelected ? 12.5 : 11,
            weight: isSelected ? .semibold : .medium
          )
        )
        .foregroundStyle(
          isSelected
            ? Color.accentColor.opacity(0.72)
            : Color.primary.opacity(0.5)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .frame(width: layout.estimatedSize.width)
        .contentShape(Rectangle())
    }
    .buttonStyle(HubElasticButtonStyle())
    .position(
      x: diameter / 2 + offset.x,
      y: diameter / 2 + offset.y
    )
    .animation(
      .spring(duration: 0.46, bounce: 0.36, blendDuration: 0.08),
      value: store.selectedFolderID
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

  private func displayedOffset(
    for layout: HubLabelLayout,
    selected: Bool
  ) -> CGPoint {
    guard selected else { return layout.centerOffset }
    let direction = store.branchDirection.normalized(
      or: CGVector(dx: 1, dy: 0)
    )
    let horizontalExtent = abs(direction.dx) * layout.estimatedSize.width / 2
    let verticalExtent = abs(direction.dy) * layout.estimatedSize.height / 2
    let radius = diameter / 2 - max(horizontalExtent, verticalExtent) - 9
    let proposed = CGPoint(
      x: direction.dx * radius,
      y: direction.dy * radius
    )
    return HubWindowControls.separatingLabelFromControls(
      proposed,
      size: layout.estimatedSize,
      diameter: diameter
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

private struct HubElasticButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.88 : 1)
      .brightness(configuration.isPressed ? 0.08 : 0)
      .animation(
        .interactiveSpring(duration: 0.24, extraBounce: 0.28),
        value: configuration.isPressed
      )
  }
}

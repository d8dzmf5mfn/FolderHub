import SwiftUI

struct ChildDirectoryBubbleView: View {
  @Bindable var store: ChildDirectoryStore

  @State private var isHovered = false
  @State private var isDragHandleHovered = false

  private let glassOpticalOpacity = 0.55

  var body: some View {
    ZStack {
      bubbleShape
        .fill(.clear)
        .glassEffect(
          .clear.interactive(),
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
    .frame(width: Self.size.width, height: Self.size.height)
    .contentShape(bubbleShape)
    .scaleEffect(isHovered ? 1.008 : 1)
    .brightness(isHovered ? 0.02 : 0)
    .animation(
      .interactiveSpring(duration: 0.24, extraBounce: 0.18),
      value: isHovered
    )
    .onHover { isHovered = $0 }
    .allowsWindowActivationEvents(true)
    .accessibilityLabel("\(store.title) folder contents")
  }

  private var dragHeader: some View {
    ZStack {
      HStack {
        Text(store.title)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(Color.primary.opacity(0.5))
          .lineLimit(1)
          .truncationMode(.middle)

        Spacer(minLength: 0)
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
      .accessibilityLabel("Move \(store.title) branch")
      .accessibilityHint("Drag to move this branch")
    }
    .frame(height: DragCollisionMetrics.branchHitSize.height)
  }

  @ViewBuilder
  private var contents: some View {
    if store.isLoading, store.items.isEmpty {
      ProgressView()
        .controlSize(.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let errorMessage = store.errorMessage {
      Text(errorMessage)
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if store.items.isEmpty {
      Text("Empty")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(store.items) { item in
            childRow(item)
          }
        }
        .padding(.vertical, 5)
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

  private func childRow(_ item: DirectoryItem) -> some View {
    let isSelected = store.selectedItemID == item.id
    return Button {
      store.activate(item)
    } label: {
      Text(item.name)
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
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        store.open(item)
      }
    )
    .background(
      Capsule()
        .fill(
          isSelected
            ? Color.accentColor.opacity(0.08)
            : Color.clear
        )
    )
    .contextMenu {
      Button(item.isNavigableDirectory ? "Open Branch" : "Open") {
        store.open(item)
      }
      Button("Quick Look") {
        store.preview(item)
      }
      Button("Show in Finder") {
        store.reveal(item)
      }
    }
    .accessibilityLabel(item.name)
    .accessibilityValue(item.isNavigableDirectory ? "Folder" : "File")
  }

  private var bubbleShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 48, style: .continuous)
  }

  static var size: CGSize {
    let outset = HubPresentationMetrics.branchInteractionOutset
    return CGSize(
      width: HubPresentationMetrics.branchSize.width + outset * 2,
      height: HubPresentationMetrics.branchSize.height + outset * 2
    )
  }
}

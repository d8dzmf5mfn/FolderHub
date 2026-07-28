import AppKit
import SwiftUI

enum BubbleResizeMetrics {
  static let hitSize: CGFloat = 34
  static let visualSize: CGFloat = 24
  static let glyphSize: CGFloat = 13
}

struct BubbleResizeHandle: View {
  let size: CGSize
  let onResize: (CGSize) -> Void

  @State private var dragStartSize: CGSize?
  @State private var isHovered = false

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(
          Color.accentColor.opacity(
            isHovered || dragStartSize != nil ? 0.28 : 0.16
          )
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(
              Color.accentColor.opacity(
                isHovered || dragStartSize != nil ? 0.48 : 0.28
              ),
              lineWidth: 0.75
            )
        }

      ResizeCornerGlyph()
        .stroke(
          Color.accentColor.opacity(
            isHovered || dragStartSize != nil ? 1 : 0.78
          ),
          style: StrokeStyle(
            lineWidth: 1.4,
            lineCap: .round
          )
        )
        .frame(
          width: BubbleResizeMetrics.glyphSize,
          height: BubbleResizeMetrics.glyphSize
        )
    }
    .frame(
      width: BubbleResizeMetrics.visualSize,
      height: BubbleResizeMetrics.visualSize
    )
    .frame(
      width: BubbleResizeMetrics.hitSize,
      height: BubbleResizeMetrics.hitSize
    )
    .contentShape(Rectangle())
    .padding(4)
    .onHover { hovered in
      isHovered = hovered
      if hovered {
        NSCursor.resizeLeftRight.set()
      } else {
        NSCursor.arrow.set()
      }
    }
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          if dragStartSize == nil {
            dragStartSize = size
          }
          guard let dragStartSize else { return }
          onResize(
            BubbleResizePolicy.clamped(
              CGSize(
                width: dragStartSize.width + value.translation.width * 2,
                height: dragStartSize.height + value.translation.height * 2
              )
            )
          )
        }
        .onEnded { _ in
          dragStartSize = nil
        }
    )
    .help("Drag this corner to resize all folder panels")
    .accessibilityLabel("Resize folder panels")
    .accessibilityHint("Drag down and right to make every panel larger")
  }
}

private struct ResizeCornerGlyph: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let maxX = rect.maxX - 1
    let maxY = rect.maxY - 1

    path.move(to: CGPoint(x: rect.minX + 2, y: maxY))
    path.addLine(to: CGPoint(x: maxX, y: rect.minY + 2))

    path.move(to: CGPoint(x: rect.midX, y: maxY))
    path.addLine(to: CGPoint(x: maxX, y: rect.midY))

    path.move(to: CGPoint(x: maxX - 3, y: maxY))
    path.addLine(to: CGPoint(x: maxX, y: maxY - 3))

    return path
  }
}

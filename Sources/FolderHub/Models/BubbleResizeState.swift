import CoreGraphics
import Observation

@Observable
@MainActor
final class BubbleResizeState {
  private(set) var size: CGSize

  @ObservationIgnored var onResize: ((CGSize) -> Void)?

  init(size: CGSize = HubPresentationMetrics.branchSize) {
    self.size = BubbleResizePolicy.clamped(size)
  }

  func resize(to proposedSize: CGSize) {
    let newSize = BubbleResizePolicy.clamped(proposedSize)
    guard newSize != size else { return }
    size = newSize
    onResize?(newSize)
  }
}

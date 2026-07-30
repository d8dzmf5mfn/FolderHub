import SwiftUI
import Testing

@testable import FolderHub

@Suite("First mouse hosting view")
@MainActor
struct FirstMouseHostingViewTests {
  @Test("Inactive folder panels accept the click that activates them")
  func acceptsFirstMouse() {
    let hostingView = FirstMouseHostingView(rootView: EmptyView())

    #expect(hostingView.acceptsFirstMouse(for: nil))
  }
}

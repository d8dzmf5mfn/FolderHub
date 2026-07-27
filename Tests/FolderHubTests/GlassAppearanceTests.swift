import Foundation
import Testing

@testable import FolderHub

@Suite("Glass appearance")
struct GlassAppearanceTests {
  @Test("Default preserves the current optical strength")
  func defaultOpacity() {
    #expect(
      GlassAppearance.opticalOpacity(
        for: GlassAppearance.defaultTransparency
      ) == 0.55
    )
  }

  @Test("Transparency is clamped and maps to optical opacity")
  func transparencyMapping() {
    #expect(GlassAppearance.opticalOpacity(for: -1) == 1)
    #expect(GlassAppearance.opticalOpacity(for: 0.25) == 0.75)
    #expect(GlassAppearance.opticalOpacity(for: 1) == 0)
    #expect(GlassAppearance.opticalOpacity(for: 2) == 0)
  }

  @Test("Percentage is rounded and clamped")
  func percentage() {
    #expect(GlassAppearance.percentage(for: -1) == 0)
    #expect(GlassAppearance.percentage(for: 0.456) == 46)
    #expect(GlassAppearance.percentage(for: 2) == 100)
  }

  @Test("Shared state persists and reloads after its view disappears")
  @MainActor
  func persistence() {
    let suiteName = "GlassAppearanceTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let first = GlassAppearanceStore(defaults: defaults)

    first.setTransparency(0.73)
    let reloaded = GlassAppearanceStore(defaults: defaults)

    #expect(first.transparency == 0.73)
    #expect(reloaded.transparency == 0.73)
    #expect(reloaded.percentage == 73)
    #expect(reloaded.opticalOpacity == 0.27)
  }

  @Test("Persisted transparency is clamped")
  @MainActor
  func persistedClamping() {
    let suiteName = "GlassAppearanceTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = GlassAppearanceStore(defaults: defaults)

    store.setTransparency(4)

    #expect(store.transparency == 1)
    #expect(
      defaults.double(forKey: GlassAppearance.transparencyKey) == 1
    )
  }
}

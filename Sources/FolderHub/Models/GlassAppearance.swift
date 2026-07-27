import Foundation
import Observation

enum GlassAppearance {
  static let transparencyKey = "FolderHub.glassTransparency.v2"
  static let defaultTransparency = 0.45

  static func opticalOpacity(for transparency: Double) -> Double {
    1 - min(max(transparency, 0), 1)
  }

  static func percentage(for transparency: Double) -> Int {
    Int((min(max(transparency, 0), 1) * 100).rounded())
  }
}

@Observable
@MainActor
final class GlassAppearanceStore {
  static let shared = GlassAppearanceStore()

  private(set) var transparency: Double
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    transparency =
      defaults.object(forKey: GlassAppearance.transparencyKey) as? Double
      ?? GlassAppearance.defaultTransparency
  }

  var opticalOpacity: Double {
    GlassAppearance.opticalOpacity(for: transparency)
  }

  var percentage: Int {
    GlassAppearance.percentage(for: transparency)
  }

  func setTransparency(_ value: Double) {
    let normalized = min(max(value, 0), 1)
    guard transparency != normalized else { return }
    transparency = normalized
    defaults.set(normalized, forKey: GlassAppearance.transparencyKey)
  }
}

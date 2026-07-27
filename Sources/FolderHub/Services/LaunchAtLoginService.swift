import ServiceManagement

@MainActor
struct LaunchAtLoginService {
  var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ isEnabled: Bool) throws {
    if isEnabled {
      if SMAppService.mainApp.status != .enabled {
        try SMAppService.mainApp.register()
      }
    } else if SMAppService.mainApp.status == .enabled
      || SMAppService.mainApp.status == .requiresApproval
    {
      try SMAppService.mainApp.unregister()
    }
  }
}

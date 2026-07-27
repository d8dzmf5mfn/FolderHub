import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var panelController: DesktopPanelController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    let store = HubStore.shared
    panelController = DesktopPanelController(store: store)
    panelController?.show()
    store.synchronizeManagedLibrary()
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    HubStore.shared.synchronizeManagedLibrary()
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    panelController?.show()
    NSApp.activate(ignoringOtherApps: true)
    return true
  }
}

@main
struct FolderHubApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  private let store = HubStore.shared

  var body: some Scene {
    MenuBarExtra("Folder Hub", systemImage: "circle.grid.cross") {
      Button("Add Folder…", systemImage: "folder.badge.plus") {
        store.chooseAndAddFolder()
      }
      Button("Show Hub", systemImage: "circle") {
        store.showHub()
      }
      Button("Center Hub", systemImage: "scope") {
        store.centerHub()
      }
      Button("Minimize Hub", systemImage: "minus.circle") {
        store.minimizeHub()
      }
      Button(
        store.isHubPinned ? "Unpin Hub" : "Keep Hub on Top",
        systemImage: store.isHubPinned ? "pin.slash" : "pin"
      ) {
        store.toggleHubPinned()
      }
      Button("Open FolderHubLibrary", systemImage: "folder") {
        store.revealManagedLibrary()
      }
      Button("Collapse", systemImage: "arrow.down.right.and.arrow.up.left") {
        store.collapse()
      }
      .disabled(store.selectedFolderID == nil)

      Divider()

      SettingsLink {
        Label("Settings…", systemImage: "gearshape")
      }

      Divider()

      Button("Quit Folder Hub", systemImage: "power") {
        NSApplication.shared.terminate(nil)
      }
    }

    Settings {
      SettingsView(store: store)
    }
  }
}

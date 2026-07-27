import SwiftUI

struct SettingsView: View {
  @Bindable var store: HubStore

  var body: some View {
    Form {
      Section("Behavior") {
        Toggle(
          "Show hidden files",
          isOn: Binding(
            get: { store.showHiddenFiles },
            set: { store.showHiddenFiles = $0 }
          )
        )
        Toggle(
          "Launch at login",
          isOn: Binding(
            get: { store.isLaunchAtLoginEnabled },
            set: { store.setLaunchAtLogin($0) }
          )
        )
      }

      Section("Managed folders") {
        LabeledContent(
          "Capacity",
          value: "\(store.folders.count) of \(HubStore.maximumFolderCount)"
        )
        Button("Add Folder…") {
          store.chooseAndAddFolder()
        }
        Button("Open FolderHubLibrary") {
          store.revealManagedLibrary()
        }
        Button("Remove All", role: .destructive) {
          store.clearAllFolders()
        }
        .disabled(store.folders.isEmpty)
      }

      Section {
        Text(
          "New folders move into ~/FolderHubLibrary. Removing a reference "
            + "never deletes the real folder."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(width: 420, height: 300)
    .navigationTitle("Folder Hub Settings")
  }
}

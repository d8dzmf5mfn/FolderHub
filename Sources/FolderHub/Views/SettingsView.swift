import SwiftUI

struct SettingsView: View {
  @Bindable var store: HubStore
  @Bindable private var glassAppearance = GlassAppearanceStore.shared

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
        Toggle(
          "Keep Folder Hub on top",
          isOn: Binding(
            get: { store.isHubPinned },
            set: { store.setHubPinned($0) }
          )
        )
        LabeledContent("Glass transparency") {
          HStack(spacing: 8) {
            Slider(
              value: Binding(
                get: { glassAppearance.transparency },
                set: { glassAppearance.setTransparency($0) }
              ),
              in: 0...1
            )
            .frame(width: 150)
            Text("\(glassAppearance.percentage)%")
              .monospacedDigit()
              .frame(width: 38, alignment: .trailing)
          }
        }
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
    .frame(width: 440, height: 460)
    .navigationTitle("Folder Hub Settings")
  }
}

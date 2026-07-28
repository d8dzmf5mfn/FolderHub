# Folder Hub

Folder Hub is a native macOS 26 desktop utility that moves user-selected folders
into `~/FolderHubLibrary` and presents them through compact Liquid Glass folder
trees. It never replaces Finder.

## Requirements

- macOS 26 or later
- Xcode 26 or later for source builds

## Run from source

```bash
./script/build_and_run.sh
```

The Codex desktop Run action uses the same script. Optional modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

## Interaction

- Drag a folder from Finder onto the glass Hub to move it into
  `~/FolderHubLibrary`; a Desktop folder therefore disappears from the Desktop.
- Drag regular files onto the Hub to move them into
  `~/FolderHubLibrary/Inbox`. Inbox is added to the Hub automatically.
- Click a folder name to open its compact, scrollable contents in a separate
  spring-animated glass tree beside the Hub.
- Drag the outer glass edge of an expanded branch beyond the detach threshold
  to turn it into a standalone desktop bubble. Use Escape, Collapse, or
  **Return to Hub** from its context menu to close it.
- Use the Pin control on the Hub or any child-folder bubble to keep that window
  above other apps. Child bubbles can be pinned independently.
- Child-folder bubbles stay open when the main branch retracts or changes.
  Close a child bubble explicitly with its **×** button.
- Minimize the center Hub without minimizing or closing child-folder bubbles.
- Adjust glass transparency from 0% to 100% in Settings; changes apply live to
  the Hub and every branch bubble.
- Click a subfolder to navigate into it. Press Backspace to go up.
- Double-click a file to open it; press Space for Quick Look.
- Drag any file row from a branch or child bubble into another app to attach or
  upload that file using the standard macOS file drag payload.
- Right-click items for rename, move, new folder, trash, and reveal actions.
- Press Escape to collapse the branch.

Folder Hub stores local bookmark data and never uploads file metadata. Use
**Move Back to Desktop** from a folder name’s context menu to restore it.
Folders moved directly into `~/FolderHubLibrary` are discovered when Folder Hub
launches or becomes active. If registration or state saving fails during an
import, Folder Hub moves the folder back to its original location.

## Unsigned GitHub builds

Release archives are ad-hoc signed, not Developer ID signed or notarized.
Gatekeeper will therefore block the first normal launch:

1. Move `FolderHub.app` into `/Applications`.
2. Try to open it once.
3. Open **System Settings → Privacy & Security**.
4. Choose **Open Anyway** for Folder Hub.

Only download release assets from the project’s GitHub Releases page and verify
the archive against `SHA256SUMS`.

## Package a release

```bash
./script/package_release.sh 0.1.3
```

The script builds a universal app, applies an ad-hoc signature, validates the
bundle, and writes the DMG, ZIP, and checksum file under `dist/release/`.

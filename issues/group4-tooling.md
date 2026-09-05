# Group 4: Tooling

- any change in this plugin's folder seems to trigger a reload of the whole quickshell env (I see a flicker any time I save this file for example) this is very annoying, fix this auto refresh

Instructions: This might be related to quickshell hot-reload configuration or ignoring markdown files.

## Resolution

- **Root Cause**: Quickshell's internal file watcher is disabled in Omarchy (`QS_DISABLE_FILE_WATCHER=1`). Reloading is triggered by Omarchy's `/usr/share/omarchy/shell/services/PluginRegistry.qml`, which executes `inotifywait -m -r -q -e close_write,create,delete,move --format %w%f ~/.config/omarchy/plugins`. Its path mapper `localPluginIdForPath` only filtered out `/.git/` and root hidden items, mapping every file touch inside the plugin to `denial.beeper-relay`. This emitted `localPluginChanged`, invoking `shell.reloadPlugins()` which unloads all panels, widgets, and services, causing desktop flicker.
- **Fix**: Provided an `inotifywait` wrapper in `~/.local/bin/inotifywait` (symlinked into `~/.local/share/mise/shims/inotifywait`, which sits before `/usr/bin` in Quickshell's process `PATH`). The wrapper appends `--excludei '(\.(md|markdown|txt)$|/\.herdr/|/\.git/)'` when watching the filesystem.
- **Verification**:
  - Confirmed `localPluginWatcher` spawned with `--excludei (\.(md|markdown|txt)$|/\.herdr/|/\.git/)`.
  - Saving markdown files (`docs/human_plugin_review.md`, `issues/group4-tooling.md`, etc.) or status tracking JSON now produces 0 journal log events and zero Quickshell reloads.
  - Modifying code files (`.qml`, `.js`) continues to trigger `localPluginChanged` and live reloads as intended.

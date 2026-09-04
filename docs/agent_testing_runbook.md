# Relay — Agent Testing Runbook

This runbook describes how automated agents and CI/CD tools test, drive, and verify the Relay Beeper triage drawer (`denial.beeper-relay`) in a live Omarchy / Hyprland / Quickshell session.

---

## 1. Quick Start

Run the full automated test and verification loop:

```bash
node tools/drive-relay.mjs verify-loop
```

This command executes:
1. **Pre-flight Checks**: Runs `make check` (plugin validation, qmllint, unit tests, McCabe complexity gate) and probes local Beeper Desktop port (`:23373`).
2. **Baseline Capture**: Ensures the drawer is hidden, waits for compositor settle (1200ms), and captures a pixel-exact cropped baseline screenshot under the bar icon.
3. **Summon & Capture**: Issues `omarchy-shell shell summon denial.beeper-relay`, waits for layer-shell surface mapping and animation (1500ms), and captures the open drawer screenshot.
4. **Assertions**:
   - Compares SHA-256 hashes (`open.png` != `closed_before.png`).
   - Runs OCR (`tesseract`) to verify live UI rendering (`Connection Error`, `unauthorized`, `credentials`, `Retry`, `Beeper`).
5. **Dismiss & Clean Settle**: Issues `omarchy-shell shell hide denial.beeper-relay`, waits for fade-out unmap (1200ms), captures `closed_after.png`, and verifies it matches `closed_before.png` (clean dismiss assertion).

---

## 2. CLI Tooling Reference (`tools/drive-relay.mjs`)

The driver script exposes subcommands for granular inspection and control:

| Command | Description | Example |
| :--- | :--- | :--- |
| `status` | Reports plugin install status, enabled state, and bar widget geometry | `node tools/drive-relay.mjs status` |
| `open` | Summons the drawer on the focused monitor via Omarchy shell IPC | `node tools/drive-relay.mjs open` |
| `close` | Hides the drawer cleanly | `node tools/drive-relay.mjs close` |
| `toggle` | Toggles drawer visibility | `node tools/drive-relay.mjs toggle` |
| `locate` | Computes pixel-exact global coordinates for `grim` crop | `node tools/drive-relay.mjs locate` |
| `screenshot <file>` | Captures a cropped screenshot of the drawer area | `node tools/drive-relay.mjs screenshot /tmp/snap.png` |
| `ocr <file>` | Runs `tesseract` against a screenshot and prints recognized text | `node tools/drive-relay.mjs ocr /tmp/snap.png` |
| `preflight` | Runs test suite and probes Beeper Desktop port | `node tools/drive-relay.mjs preflight` |
| `verify-loop [outdir]`| Executes the full 5-stage automated assertion pipeline | `node tools/drive-relay.mjs verify-loop` |

---

## 3. Architecture & Mechanics

### Bar Widget & Dropdown Placement
Relay is implemented as a `bar-widget` plugin (`BarWidget.qml`).
- The top bar icon button is a `BarIconButton` (`󰍡`) placed in `bar.layout.right`.
- The popup is a `KeyboardPanel` that anchors directly to `button`.
- `KeyboardPanel` is a full-screen `WlrLayershell` overlay surface that calculates the card origin directly below the bar icon:
  ```text
  cardX = anchorScreenPos.x + anchorW / 2 - contentWidth / 2
  cardY = barH + gap
  ```

### Screen Coordinate Resolution (`tools/drive-geometry.mjs`)
In multi-monitor setups (e.g. `DP-1` at `x: 3840`, `DP-2` at `x: 1920`), `grim -g` requires global compositor coordinates:
1. `hyprctl monitors -j` identifies the focused monitor and its offset (`monitor.x`, `monitor.y`).
2. `omarchy-shell shell debugBarGeometry` reports widget position relative to the bar (`widget.x`, `widget.y`).
3. `calculateCropGeometry()` computes the exact bounding box centered under the bar icon with padding.

### IPC Routing & Multi-Monitor Isolation
- In `BarWidget.qml`, `manageIpc` is set to `false`. This prevents duplicate per-monitor `IpcHandler` registrations when multiple monitors each draw a top bar.
- Driving commands route through `omarchy-shell shell summon denial.beeper-relay` and `omarchy-shell shell hide denial.beeper-relay`.
- `Bar.qml` uses `BarModel.pickPanelSlot(candidates, focusedScreenName())` to summon the panel strictly on whichever monitor the user/cursor has focused.

---

## 4. Critical Engineering Gotchas

### Quickshell Local Plugin File Watcher
> [!WARNING]
> Quickshell watches local plugin directories (`~/.config/omarchy/plugins/<id>/`) for file changes and triggers an automatic reload (`onLocalPluginChanged`).
> Writing test artifacts, logs, or screenshots into the plugin directory will instantly trigger a reload and dismiss any open panels!
>
> **Rule**: Always write test artifacts and screenshots outside the plugin directory (e.g. `/tmp/omarchy-relay-verify` or `~/.cache/`). `verify-loop` defaults to `/tmp/omarchy-relay-verify`.

### Layer-Shell Settle Latency
> [!NOTE]
> `KeyboardPanel` has a 140ms fade-out cubic animation and releases `Bar.activePopout` on unmap. Rapid back-to-back IPC calls can race Qt/Wayland surface commits.
> Automated drive scripts must wait at least 800–1200ms between `hide` and subsequent `summon` actions to ensure clean compositor state.

---

## 5. Manual Verification Checklist for Human Drive

When performing a human signoff drive:
1. **Top Bar Icon**: Verify the chat icon `󰍡` is visible in the right section of the top bar. Hover tooltip should display `Relay (Beeper)`.
2. **Mouse Click**: Click the icon to drop down the drawer. Click outside (or on the bar) to verify clean dismissal.
3. **Hotkeys**:
   - `Esc`: Closes drawer or navigates back from conversation.
   - `j` / `k` (or `Down` / `Up`): Navigates unread chat list.
   - `Enter`: Enters selected conversation.
   - `c`: Focuses message composer in conversation.
   - `r`: Retries connection (on error) or marks active chat read.
   - `o`: Triggers `beeper://` deep link to open conversation in Beeper Desktop.
4. **Empty & Error States**:
   - If Beeper Desktop is stopped, drawer renders `Connection Error` with `Retry`.
   - If unread inbox is empty, drawer renders inbox zero state.

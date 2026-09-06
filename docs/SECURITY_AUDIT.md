# Security Audit: denial.beeper-relay

**Date**: 2026-09-06
**Auditor**: Claude Opus 4.6 (Thinking)
**Scope**: Full source review + live API probe
**Spec reference**: `relay_beeper_triage_spec.md` §21 (Security and Privacy)

---

## 1. Threat Model

### 1.1 What Relay Handles

- **Beeper access token** — grants full read/write to all bridged messaging accounts
- **Chat metadata** — room IDs, titles, networks, account IDs, timestamps
- **Message content** — plaintext bodies of unread conversations
- **Sender identities** — names, sender IDs across Signal, Telegram, Slack, etc.

### 1.2 Attack Surface

```
┌─────────────────────────────────────────────────────┐
│ Beeper Desktop (localhost:23373)                    │
│   HTTP API — all chats, all messages, send/read     │
│   Auth: static Bearer token                         │
└──────────────────┬──────────────────────────────────┘
                   │ HTTP (TCP 127.0.0.1)
┌──────────────────▼──────────────────────────────────┐
│ Relay Plugin (Quickshell, same UID)                 │
│   Reads: token file, env var                        │
│   Writes: pins.json (chat metadata + previews)      │
│   Holds: authToken in QML property (process memory) │
└──────────────────┬──────────────────────────────────┘
                   │ filesystem
┌──────────────────▼──────────────────────────────────┐
│ ~/.config/beeper-relay/                             │
│   token       — Beeper API credential               │
│   pins.json   — pinned chat snapshots               │
└─────────────────────────────────────────────────────┘
```

### 1.3 Threat Actors

| Actor | Access | Goal |
|---|---|---|
| **Other local user** | Separate UID on same machine | Read messages, steal token |
| **Same-UID malware** | npm postinstall, rogue extension, compromised app | Full API access, exfiltrate messages |
| **Physical/disk access** | Stolen laptop, forensic imaging | Read persisted chat data and token |
| **Network attacker** | Same LAN, no local account | Reach localhost API (blocked — 127.0.0.1 only) |

---

## 2. Current Trust Model

**Implicit assumption: same UID = fully trusted.**

This is the standard Unix model and matches Quickshell's plugin architecture (§20: "runs unsandboxed with the user's permissions"). The plugin does not attempt to defend against same-UID attackers, which is a reasonable default for a desktop shell component.

### 2.1 What the Plugin Gets Right

| Control | Implementation | Evidence |
|---|---|---|
| **Localhost-only transport** | `defaultBaseUrl = "http://127.0.0.1:23373"` | `BeeperApi.js:4` |
| **No token logging** | Zero `console.log` calls referencing tokens in production paths | grep audit |
| **No message body logging** | All `console.log` in `tools/` only (dev), never `services/` or `models/` | grep audit |
| **PlainText rendering** | All `Text {}` use `textFormat: Text.PlainText` or default (PlainText) | No `Text.RichText` or `Text.StyledText` anywhere |
| **HTML stripping** | `ChatRowHelper.js:stripHtml()` actively strips tags from snippets | `ChatRowHelper.js:3` |
| **URL encoding** | All HTTP path params use `encodeURIComponent(chatId)` | `BeeperApi.js`, `BeeperService.qml` |
| **No secrets in git** | No `.env`, `.key`, `.pem`, token files committed | git history audit |
| **Unsupported message guard** | Non-TEXT messages normalized to `text: null` (§11) | `TriageModel.js:101-103` |
| **Bearer auth** | Both XHR and fetch paths set `Authorization: Bearer` header | `BeeperApi.js:54-55`, `BeeperService.qml:613-614` |
| **Synthetic test fixtures** | No real chat IDs, tokens, or PII in test data | `tests/fixtures/` |
| **Explicit error classification** | Raw HTTP details never surfaced to UI; mapped to semantic codes | `TriageModel.js:271-279` |
| **Beeper Desktop enforces auth** | Confirmed live: unauthenticated `GET` → `401` | API probe |

---

## 3. Findings

### 3.1 🔴 HIGH — `pins.json` is world-readable and contains chat metadata

**File**: `~/.config/beeper-relay/pins.json`
**Permissions**: `644` (rw-r--r--)

The file contains:

- Real Matrix room IDs (e.g. `!EWHKJwxKdhoNLDcMGD:beeper.com`)
- Chat titles ("VAULT", "HAL")
- Network and account identifiers ("Telegram", "matrix")
- Timestamps of last activity
- **Message preview text** (when previews were loaded at pin time)

Any local user can `cat` this file and learn who you're talking to, on what networks, and potentially read message snippets.

**Root cause**: Quickshell's `FileView` with `atomicWrites: true` creates files using the process umask (typically 022 → 644). The `savePins()` function (`BeeperService.qml:112-118`) does not restrict permissions or strip sensitive content before writing.

### 3.2 🟡 MEDIUM — `pins.json` persists message content unnecessarily

**File**: `BeeperService.qml:112-118`

The `retainedPins` object stores full normalized chat snapshots including the `preview` field, which contains message text, sender name, and timestamp. This data is written to disk on every pin state change.

The pin feature only needs the **chat ID and display metadata** (title, network, isPinned) — not message content. Persisting previews violates the spec's "avoid unnecessary filesystem writes" principle (§21) and expands the data-at-rest attack surface.

### 3.3 🟡 MEDIUM — Shell injection in `drive-relay.mjs` (dev tooling)

**File**: `tools/drive-relay.mjs:76-90`

```js
run(`grim -g "${geom.geomString}" "${outFile}"`);            // line 79
tryRun(`tesseract "${imagePath}" stdout --oem 1 --psm 6`);   // line 85
run(`sha256sum "${path}"`);                                   // line 90
```

`outFile`, `imagePath`, and `geomString` are interpolated into shell strings passed to `execSync`. If any argument contains shell metacharacters (`$(...)`, `` ` ``, `;`, `|`), arbitrary commands execute as the user.

**Mitigating factors**: These are dev-only CLI tools, not in the production QML path. `PLUGIN_ID` is hardcoded. But `outFile` and `imagePath` come from CLI `process.argv`, making this exploitable if another script calls `drive-relay.mjs screenshot '$(malicious).png'`.

### 3.4 🟢 LOW — `authToken` held as QML property for full process lifetime

**File**: `BeeperService.qml:17`

```qml
property string authToken: ""
```

The token is loaded at `Component.onCompleted` and persists in the QML engine's memory until the process exits. QML properties are introspectable via the QObject meta-object system. In Quickshell's current single-process unsandboxed model this is acceptable, but if plugin sandboxing or cross-plugin IPC is ever added, this becomes a credential leak surface.

### 3.5 🟢 LOW — `BEEPER_ACCESS_TOKEN` environment variable

**File**: `BeeperService.qml:150-153`

Environment variables are readable via `/proc/<pid>/environ` by any same-UID process. This is the standard pattern for CLI auth (cf. `GITHUB_TOKEN`, `AWS_SECRET_ACCESS_KEY`) and is acceptable for a local desktop tool, but the file-based path is slightly more restrictable.

### 3.6 🟢 LOW — Hardcoded fallback path

**File**: `BeeperService.qml:25, 56`

```js
(Quickshell.env("HOME") || "/home/denial")
```

If `HOME` is unset, the plugin would attempt to read `/home/denial/.config/beeper-relay/token`. Not a real risk (HOME is always set in desktop sessions) but a portability smell.

---

## 4. Trust Model Analysis

### 4.1 Can an Attacker Read Messages?

**Confirmed yes**, via two paths:

| Path | Requires | Gets |
|---|---|---|
| **Read `pins.json`** | Any local user (file is 644) | Chat titles, room IDs, networks, timestamps, possibly message previews |
| **Steal token → hit API** | Same UID *or* token file ≥644 | Full read/write access to all Beeper chats and messages |

**Live verification**:

```
$ curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:23373/v1/chats/search?unreadOnly=true
401                                          # ← without token: blocked

$ curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $(cat ~/.config/beeper-relay/token)" \
    http://127.0.0.1:23373/v1/chats/search?unreadOnly=true
200                                          # ← with token: full access
```

### 4.2 What the Plugin Can and Cannot Fix

| Threat | Plugin can fix? | How |
|---|---|---|
| Other-UID reads pins.json | ✅ | Directory permissions, strip previews |
| Other-UID reads token | ✅ | Directory permissions (token is already 600) |
| Same-UID steals token from file | ❌ | Fundamental Unix — same UID can read owner files |
| Same-UID hits localhost API directly | ❌ | TCP has no caller identity |
| Same-UID reads `/proc/pid/environ` | ❌ | Fundamental Unix |
| Same-UID reads `/proc/pid/mem` | ❌ | Fundamental Unix — reducible by zeroing token |

### 4.3 The Fundamental Limitation

Beeper Desktop exposes an **HTTP API on a TCP socket** authenticated by a **long-lived static token**. TCP `127.0.0.1` provides no caller identity — any same-UID process can connect. The token file is the only barrier, and same-UID processes can always read owner-readable files.

A stronger transport from Beeper Desktop would be:
- **Unix domain socket** with `SO_PEERCRED` — kernel-verified PID/UID, no token file needed
- **Per-session ephemeral tokens** with short TTL
- **Capability-scoped tokens** — e.g., read-only, unread-counts-only

These are upstream changes outside this plugin's scope.

---

## 5. Recommended Trust Model: 3-Layer Defense-in-Depth

### Layer 0 — Lock the directory (immediate, no code change)

```bash
chmod 700 ~/.config/beeper-relay/
```

This single command protects `token`, `pins.json`, and any future files from all other local users. The plugin itself runs as the owning user, so no functionality changes.

**Optionally** document this in `README.md` as a post-install step.

### Layer 1 — Minimize data at rest (plugin change, small)

Strip `preview` content from retained pin snapshots before writing to disk. The pin feature only needs chat identity and display metadata — previews are re-fetched on next drawer open.

In `BeeperService.qml`, modify `savePins()`:

```js
function savePins() {
    if (root.restoringPins) return;
    var safeRetained = {};
    var keys = Object.keys(root.retainedPins);
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var snap = root.retainedPins[k];
        if (!snap) continue;
        safeRetained[k] = Object.assign({}, snap, { preview: null });
    }
    pinsFile.setText(JSON.stringify({
        localPins: root.localPins,
        retainedPins: safeRetained
    }));
}
```

**Impact**: `pins.json` no longer contains message text. A stolen file reveals chat names and networks, but not message content.

### Layer 2 — Shorten token lifetime in memory (plugin change, moderate)

Currently `authToken` lives for the entire process lifetime. Instead:

- **Read** the token when the drawer opens or badge poll fires
- **Zero** it (`authToken = ""`) when the drawer closes and no poll is active
- The bar widget's `BeeperService` (15s poll) holds its own short-lived copy

This shrinks the window where the token is in process memory from "always" to "drawer open + poll window." A `/proc/<pid>/mem` scraper has a much narrower target.

### Layer 3 — Upstream (Beeper Desktop, out of scope)

For the plugin to document as a known limitation:

- Beeper Desktop should offer Unix socket transport with `SO_PEERCRED`
- Beeper Desktop should support short-lived scoped tokens
- Until then, same-UID isolation is not achievable

---

## 6. Summary Matrix

| # | Severity | Finding | Remediation | Layer |
|---|---|---|---|---|
| 3.1 | 🔴 HIGH | `pins.json` world-readable (644), leaks chat metadata | `chmod 700 ~/.config/beeper-relay/` | 0 |
| 3.2 | 🟡 MED | `pins.json` persists message previews unnecessarily | Strip `preview` in `savePins()` | 1 |
| 3.3 | 🟡 MED | Shell injection in `drive-relay.mjs` dev tooling | Use `execFileSync` (array argv) | — |
| 3.4 | 🟢 LOW | `authToken` QML property lives for process lifetime | Zero on drawer close | 2 |
| 3.5 | 🟢 LOW | Env var token visible in `/proc` | Acceptable; prefer file path | — |
| 3.6 | 🟢 LOW | Hardcoded `/home/denial` fallback | Cosmetic | — |

---

## 7. Conclusion

The plugin's production code is **well-designed for its stated scope** — a local-only desktop triage drawer. It correctly avoids the most common security mistakes: no remote traffic, no token/body logging, no HTML/QML injection, proper URL encoding, and synthetic test data.

The actionable gaps are:

1. **Filesystem permissions** on `~/.config/beeper-relay/` (fix in 30 seconds)
2. **Data minimization** in `pins.json` (small code change)
3. **Shell injection** in dev tooling (moderate code change)

The same-UID threat is **not fully mitigable** within the plugin — it requires upstream changes to Beeper Desktop's API transport. This is an acceptable residual risk for a local desktop shell component, and should be documented as a known limitation.

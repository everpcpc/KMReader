---
name: xcode-mcp
description: Use when building, running, or debugging an app on a device/simulator through Xcode 26+ built-in MCP (mcpbridge), especially to drive Device Hub interactions (tap/swipe/orientation), capture screenshots and UI hierarchies, reproduce UI bugs, or triage hangs and crashes on device. Covers environments where Simulator.app no longer exists.
---

# Xcode MCP (mcpbridge + Device Hub)

Xcode 26+ ships a built-in MCP server. It exposes project actions (build, run, test, debugger) and **DeviceInteraction** tools that drive physical devices and simulators through Device Hub — the only option when Simulator.app is gone (e.g. Xcode 27 betas).

## When To Use

- Verify app behavior on a real device or simulator (taps, swipes, rotation, typing).
- Reproduce a UI/UX bug and observe the live view hierarchy or screenshots.
- Triage a hang (sample the process) or inspect runtime logs of the running app.
- Build/run/test the current scheme without leaving the terminal.

## How It Works

- The stdio bridge is `mcpbridge`, located at `$(xcode-select -p)/usr/bin/mcpbridge`. It forwards JSON-RPC to the **running Xcode** selected by `xcode-select` (override with `MCP_XCODE_PID`).
- A companion launcher `mcp-server` (same directory) manages headless mode; `enable`/`approve` need sudo and are **not** required when Xcode is already running interactively.
- Most workspace tools require a `tabIdentifier`. Do not guess it: call the tool without it and the error response lists every open window as `tabIdentifier` + `workspacePath`. Pick the matching one and retry.
- A ready-to-use generic client lives at `scripts/xcode_mcp.py` next to this file:

```bash
python3 scripts/xcode_mcp.py list-tools
python3 scripts/xcode_mcp.py schema DeviceInteractionSynthesize
python3 scripts/xcode_mcp.py call XcodeListSchemes '{}'
```

## Key Tools

| Tool | Purpose |
|---|---|
| `XcodeListSchemes` / `XcodeListRunDestinations` | Discover schemes and available devices (names, OS, simulator vs physical). |
| `BuildProject` / `RunProject` / `StopProject` | Build, run, stop the current scheme. |
| `DeviceInteractionStartWorkspaceSession` | Open a device session; args: `tabIdentifier`, `deviceIdentifier` (name/UUID/OS — fuzzy matched), `sessionIdentifier` (Title Case label). Returns `interactionSessionKey`. |
| `DeviceInteractionInstallAndRun` | Build, install, launch the app. Args: `interactionSessionKey`, `tabIdentifier`, optional one-off `commandLineArguments` / `environmentVariables` (supports `$(inherited)`). |
| `DeviceInteractionSynthesize` | Perform interactions and capture state. Args: `interactSessionKey`, `interactionCommand`. Returns `applicationState` (`Running`, `Hanging`, …) plus paths to hierarchy / screenshot / logs files. |
| `DeviceInteractionEndSession` | Close the session. Sessions are resource-heavy — always end them when done. |
| `GetConsoleOutput` | stdout/stderr/OSLog of the running app, with regex filter and tail limit. |
| `InvokeDebuggerCommand` | Send an lldb command to Xcode's active debug session (only when launched with debugging). |

## Interaction Command Syntax (`interactionCommand`)

| Command | Description |
|---|---|
| `t <x> <y> [duration]` | Tap (optional hold) |
| `d <x> <y>` | Double tap |
| `t <x1> <y1> f <x2> <y2> [duration]` | Swipe |
| `b h/p/u/d [duration]` | Hardware button: home/power/volUp/volDown |
| `orientation portrait/landscapeLeft/landscapeRight/faceUp/...` | Rotate device |
| `sender keyboard kbd <text>` | Type text (must be last in chain; `\u{XXXX}` escapes) |
| `w <seconds>` | Wait |

Chain commands with spaces, e.g. `"t 357 101 w 1 t 261 177 w 1.5"`.

## Standard Workflow

1. **Session**: `DeviceInteractionStartWorkspaceSession` with the project tab and target device.
2. **Install & run**: `DeviceInteractionInstallAndRun`.
3. **Interact loop**: `DeviceInteractionSynthesize`:
   - Before interacting, read the returned hierarchy file; it lists every element as `Type, {{x, y}, {w, h}}, label: '...', hitPoint: {cx, cy}` — **always tap the `hitPoint`/center coordinates**, never coordinates guessed from a screenshot.
   - After each interaction, re-capture and verify against the screenshot file (hierarchies can include stale or offscreen elements).
   - On unexpected result, re-capture once and retry once; then stop and report instead of retrying forever.
4. **Hang triage**: when `applicationState` is `Hanging`, the simulator app is a host process — get its pid from the hierarchy header (`Application, pid: NNN`) and run `sample <pid> 3 -file /tmp/app-sample.txt` on the host, then read the main-thread call graph. For physical devices or debug launches use `InvokeDebuggerCommand` with `bt all` instead.
5. **Cleanup**: `DeviceInteractionEndSession`. Delete any helper artifacts you saved to the repo during debugging.

## Notes

- `DeviceInteractionInstallAndRun` kills and relaunches the app; in-app state (e.g. an open reader) is not preserved — navigate back through the UI.
- Device sessions can expire between long pauses; if a call reports the session key is gone, start a fresh session and reinstall.
- Keep the app debuggable when hang-triaging: debug builds symbolicate `sample` output with file:line.

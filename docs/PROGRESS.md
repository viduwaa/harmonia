# Harmonia Progress

Updated: 2026-04-02

## Master Checklist

- [x] Discovery of current repository baseline
- [x] Architecture alignment decisions captured
- [x] Cross-IDE workspace instruction files established
- [x] Cross-IDE agent detection and warning guardrails added
- [x] Hybrid C# + GDScript routing and fallback policy added
- [x] Hybrid architecture and configuration guide documented
- [x] VS Code launch and task debugger configuration added
- [x] Additional VS Code launch profiles (editor-only and direct TestScene) added
- [x] Audio detection reliability patch and on-screen status diagnostics added
- [x] TestScene runtime fallback bootstrap for missing AudioProcessor added
- [x] Autoload-resolution retry and warning-spam suppression fix added
- [x] TestScene high-value controls: input device selector and live calibration settings added
- [x] Audio note stability-frame gating added for cleaner detections
- [x] Optional C# pitch-decision backend scaffold and GDScript fallback bridge added
- [x] C# backend instantiation fixed (ClassDB path) and capture-based YIN analyzer implemented
- [x] YIN implementation rechecked and corrected end-to-end (GDScript bridge + C# service + capture bus)
- [x] Runtime diagnostics and TestScene log panel added for audio backend troubleshooting
- [x] Live UI calibration controls (signal threshold, confidence, stable frames) fully wired to AudioProcessor
- [ ] Phase 0 Architecture Contracts implementation
- [ ] Phase 1 Core Audio Prototype implementation
- [ ] Phase 2 Battle Vertical Slice implementation
- [ ] Phase 3 Local JSON Persistence implementation
- [ ] Phase 4 Game Flow Integration implementation
- [ ] Phase 5 Hardening and migration prep

## Current Status

- Done: C# backend resolves in runtime, capture path stabilized, status/fallback diagnostics are visible, and TestScene calibration controls now apply live to detection behavior.
- Next: Close Phase 1 by adding a lightweight calibration profile save/load path in LocalDataManager, then begin BattleManager vertical slice wiring.
- Blocked: None.

## Immediate Next Actions

1. Run TestScene and verify Start/Stop capture with live frequency/note updates.
2. Tune AudioProcessor thresholds for silence/noise environments.
3. Confirm backend mode label changes to CSharpYIN during live capture; if not, inspect Godot editor .NET assembly load state.

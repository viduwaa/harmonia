# Harmonia Roadmap

## Scope

2D music-driven educational RPG prototype to production in phased vertical slices.

## Phases

### Phase 0: Architecture Contracts

- Finalize manager responsibilities and signal contracts.
- Finalize hybrid split and interop boundaries between GDScript and C# modules.
- Define shared payloads for note detection, battle resolution, and persistence writes.
- Confirm audio bus safety assumptions and startup configuration.

Implementation note (2026-04-06): Phase 0 contract baseline is documented in docs/ARCHITECTURE_CONTRACTS.md.

### Phase 1: Core Audio Prototype

- Implement AudioProcessor singleton lifecycle and microphone capture controls.
- Implement pitch detection (autocorrelation/YIN style) and Hz-to-note conversion.
- Build a test scene with start/stop control, live frequency label, and live note label.
- Add no-feedback defaults, silence floor, and basic confidence gating.

Implementation note (2026-04-06): Phase 1 is complete in current milestone scope (AudioProcessor lifecycle, capture controls, live test scene controls, confidence/noise gating, and no-feedback defaults).

### Phase 2: Battle Vertical Slice

- Implement BattleManager for target-note generation, hit grading, HP changes, and win/loss.
- Connect AudioProcessor note attempts into battle actions.
- Validate deterministic outcomes with known input cases.

### Phase 3: Local Persistence (JSON)

- Implement LocalDataManager using schema-aligned JSON documents:
  PROFILE, LEVEL, LEVEL_PROGRESS, GAME_SESSION, NOTE_ATTEMPT.
- Add versioned serialization and integrity checks.
- Track session metrics and per-note attempts.

### Phase 4: Flow Integration

- Implement GameStateManager transitions for session lifecycle.
- Wire battle outcomes to progression updates and persistence writes.
- Add failure-safe handling for partial save operations.

### Phase 5: Hardening and Migration Prep

- Add diagnostics overlay and performance/latency tuning.
- Improve calibration and noise robustness.
- Introduce storage adapter boundary for future SQLite backend swap.

Implementation note (2026-05-03): storage adapter boundary is in place, SQLite runtime behavior is enabled with in-project C# bridge support, migration-readiness required-artifact checks are adapter-aware, LocalDataManager startup rollout is sqlite-first with safe fallback, TestScene provides one-click SQLite QA cycle execution (health summary + parity + snapshot), SaveGate evidence is persisted as latest + history artifacts for merge auditing, workspace task `harmonia-verify-storage-merge-gate` validates gate artifacts plus readiness index before merge, AudioProcessor now applies adaptive noise-floor thresholding with live TestScene diagnostics for improved robustness, a non-test `PlayerHudScene` provides player-facing live pitch/threshold feedback outside debug tooling, `PlayerFlowScene` embeds that HUD as the default runtime entry with optional debug-tools handoff, the HUD surfaces gameplay-facing target prompt/hit feedback plus battle/session summary states from battle and flow managers, PlayerFlowScene includes a compact action strip for start/stop listening and quick battle reset without debug-scene dependency, both scenes share a coherent card-based visual style for player-facing runtime UX, icon slots are backed by dedicated named assets in `src/gd/assets/ui/icons` with `icon_manifest.json` mapping keys to slot nodes, the exploration slice includes zone-tiered encounter routing (Meadow Tier I/Cavern Tier II) plus Guide NPC/Relic interactable stubs with persisted spawn state, exploration interactable completion flags and zone-tiered XP/shard rewards are now persisted and surfaced in-world, PlayerHud now exposes exploration consequences plus dual shard sinks (focus and surge), shard sink telemetry is persisted and visible in ExploreWorld/HUD for balancing passes, a surge sink guardrail reduces XP below Level 2, encounter triggers save pre-battle checkpoints that are preserved if players exit mid-battle, a main menu now fronts runtime entry, and Level 01 in ExploreWorld introduces a random encounter wins gate with boss unlock flow.

## Verification Criteria

- Stable pitch and note output for sustained tones.
- Low false positives under silence/noise thresholds.
- Correct battle scoring and HP math under test scenarios.
- Save/load roundtrip integrity against required schema fields.
- Stable repeated audio start/stop cycles without leaks or crashes.

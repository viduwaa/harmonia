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

Implementation note (2026-04-06): storage adapter boundary is in place and SQLite adapter behavior is implemented with runtime SQLite detection plus JSON mirror compatibility. Remaining follow-up is runtime evidence capture (parity + snapshot exports) in a SQLite-capable environment.

## Verification Criteria

- Stable pitch and note output for sustained tones.
- Low false positives under silence/noise thresholds.
- Correct battle scoring and HP math under test scenarios.
- Save/load roundtrip integrity against required schema fields.
- Stable repeated audio start/stop cycles without leaks or crashes.

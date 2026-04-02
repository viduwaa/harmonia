# Copilot Instructions for Harmonia

Apply these rules in every conversation for this repository.

## Agent Preference

- Prioritize game-development division agents for Godot work.
- First choice for implementation: Godot Gameplay Scripter.
- For shaders: Godot Shader Developer.
- For networking: Godot Multiplayer Engineer.
- For gameplay tuning: Game Designer.
- For architecture: Software Architect plus Godot specialist validation.
- For C# systems and interop-heavy modules: Software Architect plus Senior Developer.

## Hybrid Language Policy

- Approved stack: Godot 4.x hybrid architecture using both GDScript and C#.
- Recommended split:
    - GDScript: scenes, signals, gameplay orchestration, UI integration.
    - C#: performance-critical systems, reusable service logic, tooling/data processing.
- Keep cross-language APIs narrow, typed, and manager-centered.
- Use signal/event-driven handoffs between managers and scene/UI layers.

## Cross-IDE Detection Guardrail

- Applies to OpenCode, Codex, Copilot, Antigravity, and other IDE runtimes.
- At session start, check whether preferred game-division agents/skills are detected and usable.
- If not detected, warn before implementation with this exact message:
  "Warning: Preferred Harmonia game-division agents/skills were not detected in this IDE session. Continue only with fallback agents, or switch to an environment that supports the required Godot agents for best results."
- Continue only after user confirms fallback mode.
- In fallback mode, explicitly map to the closest available specialist and state the tradeoff.
- Hybrid fallback mapping:
    - GDScript-heavy tasks -> Software Architect fallback.
    - C#-heavy tasks -> Senior Developer fallback.
    - DSP-heavy tasks -> Game Audio Engineer, else Software Architect fallback.

## Project Constraints

- Engine: Godot 4.x
- Language: strongly typed GDScript + strongly typed C# (hybrid)
- Core managers: GameStateManager, AudioProcessor, BattleManager, LocalDataManager
- Manager/UI communication: Godot signals
- Persistence now: local JSON aligned to relational schema for later SQLite migration

## Workflow

1. Read AGENTS.md before major changes.
2. Verify preferred game-division agent/skill availability in the current IDE session.
3. If unavailable, issue the required warning and ask whether to continue in fallback mode.
4. Verify hybrid toolchain readiness for C# usage in the active runtime (Godot .NET support).
5. Follow docs/ROADMAP.md for sequencing.
6. Update docs/PROGRESS.md with Done, Next, Blocked after each significant milestone.
7. Prefer practical implementation and verification over speculative planning.

## Truthfulness

- Be explicit about what is done, not done, and risky.
- Provide alternatives when constraints prevent the ideal approach.

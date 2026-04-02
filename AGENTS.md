# Harmonia Agent Policy (Cross-IDE)

## Purpose

This repository uses specialized game-development agents.
All AI coding assistants working in this repo should follow this file first.

## Default Agent Routing

1. Godot gameplay systems, scene logic, signals, singleton managers:
   Prefer: Godot Gameplay Scripter
2. Godot shaders and VFX:
   Prefer: Godot Shader Developer
3. Godot multiplayer and replication:
   Prefer: Godot Multiplayer Engineer
4. Gameplay loops, combat tuning, and progression design:
   Prefer: Game Designer
5. Narrative, lore, and dialogue systems:
   Prefer: Narrative Designer
6. Level flow and encounter layout:
   Prefer: Level Designer
7. Audio implementation and adaptive music systems:
   Prefer: Game Audio Engineer
8. Cross-cutting architecture decisions:
   Prefer: Software Architect (with Godot specialist review)
9. C# domain systems, .NET tooling, and interop-heavy backend modules:
   Prefer: Software Architect + Senior Developer

If multiple choices apply, start with the Godot-specific agent and then use generic agents only as needed.

## Hybrid Language Routing (GDScript + C#)

- Approved approach: hybrid architecture where GDScript and C# are used together in Godot 4.x.
- Default split:
    - GDScript: scenes, node composition, signals, UI glue, rapid gameplay iteration.
    - C#: performance-sensitive systems, reusable domain services, data-heavy transforms, tooling helpers.
- Interop boundary rule:
    - Keep scene-facing APIs simple and stable.
    - Avoid mixing business rules into UI scripts.
    - Prefer manager-owned signals/events for cross-language communication.
- Agent mapping by implementation type:
    - GDScript-heavy tasks: Godot Gameplay Scripter.
    - C#-heavy tasks: Software Architect + Senior Developer.
    - Mixed boundary tasks: Software Architect first, then Godot Gameplay Scripter validation.

## Cross-IDE Enforcement (OpenCode, Codex, Copilot, Antigravity)

- This policy applies in every IDE and assistant runtime.
- At conversation start, verify game-division agent availability for the active environment.
- If the preferred Godot/game agents are not detectable or callable, warn the user immediately before implementation work.
- Required warning text:
  "Warning: Preferred Harmonia game-division agents/skills were not detected in this IDE session. Continue only with fallback agents, or switch to an environment that supports the required Godot agents for best results."
- After warning, proceed only if the user confirms fallback mode.
- In fallback mode, map to the closest available specialist and explicitly state quality/risk tradeoffs.
- Hybrid fallback mapping in fallback mode:
    - GDScript-first tasks: Software Architect fallback.
    - C#-first tasks: Senior Developer fallback.
    - Audio DSP tasks: Game Audio Engineer, else Software Architect fallback.

## Mandatory Engineering Rules

- Use Godot 4.x and strongly typed GDScript.
- Use strongly typed C# for C# modules and keep naming/contracts aligned with GDScript manager APIs.
- Keep hybrid boundaries explicit: GDScript for gameplay orchestration, C# for compute/data-intensive services.
- Keep manager boundaries:
  GameStateManager, AudioProcessor, BattleManager, LocalDataManager.
- Prefer signal-driven communication between managers and UI.
- Keep functions modular and single-purpose.
- Preserve offline-first persistence and schema compatibility for future SQLite migration.

## Session Bootstrap

At the start of each new conversation, assistants should:

1. Read this file and .github/copilot-instructions.md.
2. Read docs/ROADMAP.md and docs/PROGRESS.md.
3. Verify preferred game-division agent/skill availability in the current IDE session.
4. If unavailable, issue the required warning and ask whether to continue in fallback mode.
5. Verify hybrid toolchain readiness for C# use (Godot .NET support enabled for the project/runtime).
6. Continue from the first unchecked item in the active phase.
7. Report Done, Next, Blocked in each progress update.

## Bare-Truth Policy

- State feasibility, risks, and alternatives clearly.
- Do not claim completion without verification.
- If blocked, explain why and provide the shortest viable workaround.

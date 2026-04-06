# Storage Adapters

This folder contains pluggable persistence adapters used by `LocalDataManager`.

Current adapters:

- `JsonFileStorageAdapter.gd` (default, active)
- `SqliteStorageAdapter.gd` (runtime-dependent SQLite backend with JSON mirror compatibility)
- `StorageAdapter.gd` (interface/base contract)

Behavior notes:

- If the runtime has a usable `SQLite` class, the SQLite adapter stores documents and JSONL records in `user://save/harmonia.db`.
- This project now provides that `SQLite` class via `src/csharp/Infrastructure/SQLite.cs` (GlobalClass bridge over `Microsoft.Data.Sqlite`).
- The adapter mirrors writes to JSON/JSONL files so existing diagnostics/export flows still work during migration.
- If SQLite is unavailable, `LocalDataManager` safely falls back to the JSON file adapter.

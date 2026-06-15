# Harmonia UI Icon Slots

This folder contains icon assets used by player-facing UI scenes.

## Naming Convention

- `flow_*`: icons used in `PlayerFlowScene`.
- `hud_*`: icons used in `PlayerHudScene`.
- Suffix `_icon.svg`: indicates a direct Texture2D scene asset.

## Source of Truth

Use `icon_manifest.json` as the authoritative mapping between:

1. Logical icon key
2. Physical asset file
3. Scene slot node

## Replacement Workflow

1. Keep existing filenames when replacing placeholder art to avoid scene rewiring.
2. If a filename changes, update:
    - `icon_manifest.json`
    - Any `ext_resource` path in scenes that reference that file.
3. Validate scenes after updates using project diagnostics.

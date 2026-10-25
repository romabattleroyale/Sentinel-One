# AURORA STRIKE — Target Map PBR Art Direction

## Scope

This phase brings the Blender-to-Godot pipeline closer to the supplied unlabeled target image. It changes only terrain, biome materials, lighting and the clean orthographic map-art view; labels, coordinates, grids and HUD elements stay hidden in the top-down capture.

## Blender asset generation

Source: `tools/blender/aurora_map_gen.py`

The generator creates three PNG maps per material set:
- **Albedo** — authored biome palette with multi-scale color breakup.
- **Normal** — baked tangent-space relief details. The master terrain normal is derived from the shared height field at 1024 × 1024.
- **Roughness** — per-biome roughness breakup, with separate baseline values for smooth water, rough rock, soil, vegetation and built surfaces.

The per-biome sets are 1024 × 1024: mountains, snow, forest, ocean, shallow water, desert, quarry, urban ground, asphalt, rooftops and grass. A separate terrain-master set is generated and the terrain albedo is baked at 1536 × 1536. The runtime uses the flattened master maps at `textures/biomes/terrain_master_*.png` and the material sets in `textures/biomes/<biome>/`.

The island master mesh uses 1.5 m terrain sampling, an irregular smoothed/roughened shoreline, explicit shoreline sidewalls, multi-tone vegetation batches and faceted outcrops. The generator retains the 64 sector exports and 16 named POI modules. It also publishes the master GLB and texture set into the Godot project automatically when run locally without `AURORA_OUTPUT_DIR`; CI uses a temporary output folder and copies the same assets into the project before testing.

## Godot material and lighting setup

Runtime source: `scripts/world.gd`

- **Terrain** — albedo, height-derived normal and roughness are applied as a `StandardMaterial3D` material override to `Island_Terrain_2000m`.
- **Ocean** — ultramarine albedo, low roughness (0.22), modest metallic/specular and a low-strength normal map.
- **Shallow water / lake / river / harbor** — cyan shallow-water texture, low roughness (0.18) and a softer normal.
- **Lighting** — warm directional key at rotation `(-52°, -32°, 0°)`, energy `1.5`, color `(1.00, 0.90, 0.76)`, shadows enabled with bias controls tuned for the overhead view.
- **Tone and grade** — ACES, exposure `1.12`, white reference `1.15`, brightness `1.03`, contrast `1.22`, saturation `1.26`.
- **Glow** — enabled, intensity `0.28`, strength `0.38`, bloom `0.04`.
- **Screen-space options** — SSAO radius `3.2`, intensity `1.65`, power `1.28`; SSR max steps `48`, fade-in `0.12`, fade-out `0.28`.

The project now uses **Forward+ on desktop** and keeps the **Mobile** renderer override for Android/iOS. Godot 4.5 documents SSAO and SSR as Forward+-only effects; they are not active when the mobile override is selected. On mobile, the baked normal/roughness maps, direct shadows, ACES/adjustments and the Mobile glow implementation provide the supported fallback. The graphical CI capture uses software Vulkan with Forward+ to validate the desktop art-quality path, rather than forcing Compatibility mode.

The map-art camera is orthographic, `size = 2180`, directly above the island. The top view continues to hide overlays and HUD so there are no text labels, grids or coordinates in the reference capture.

## Changed source files

- `tools/blender/aurora_map_gen.py` — PBR texture generation/binding, terrain height normal map, brighter snow, forest and red-desert palette, corrected foliage normals, improved preview exposure and local asset publishing.
- `scripts/world.gd` — Godot runtime PBR material loading/application, warm directional lighting, ACES/grade, water material settings, orthographic no-overlay map-art capture.
- `project.godot` — Forward+ desktop default plus Mobile renderer override for mobile platforms.
- `.github/workflows/AURORA_STRIKE_CAPTURE.yml` — generation and texture copy, Godotite build/import attempt, Forward+ Vulkan graphical capture.
- `ART_DIRECTION_PBR.md` — this phase report.

## Verification and remaining limitation

A Godot headless runtime check passed on the preceding phase, and Blender generation has produced its source scene, master GLB, 64 terrain sectors, 16 POI modules and a PBR texture artifact. The graphical capture workflow has had earlier failures in its Godotite/solution setup; the workflow now builds `Godotite.csproj` directly and captures with Forward+ Vulkan. The final generated runtime screenshots must still be inspected before calling the visual match complete.

This is procedural art direction, not a claim that the scene is already pixel-identical to the target image. The generator still uses stylized geometry for much of the island; the next visual acceptance gate is the new full-map runtime capture plus station, city, coast, and snow close-ups.

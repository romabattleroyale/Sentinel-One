# AURORA STRIKE — Activity Log

## 2026-10-24 — River channel, bridge alignment, and collision pass

### Reference and dependency audit performed before editing
- Consulted `Manuale_Esecutivo_Mappa_AuroraStrike_Godot.pdf`, especially coordinate convention (page 3), estimated POI anchors (page 5), tile layout (page 7), terrain height bands (page 8), coast/water (page 9), lake/river/bridges (page 10), and collision/runtime QA requirements (pages 20–26).
- Inspected `scenes/Main.tscn`: the root `AuroraStrike` is a `Node3D` with `res://scripts/world.gd`.
- Inspected `scripts/world.gd`, its dynamically attached `scripts/player.gd`, `project.godot` input actions, the Blender generator, and the runtime/capture workflows.
- Confirmed all 27 referenced `baked_city/archetypes_587/archetype_00.tscn`–`archetype_26.tscn` files exist. The configured input actions `move_forward`, `move_back`, `move_left`, `move_right`, `jump`, and `sprint` match the player controller. No scene-level signal connections are declared in `Main.tscn`; touch buttons connect in code to existing player methods.
- Existing Godot integration creates a static trimesh collision for `Island_Terrain_2000m`, but previously had no bridge-deck collision handling.

### Findings
- The terrain depression used a different river centerline formula from the visible river mesh, so the river could run over terrain rather than inside its intended channel.
- Four hard-coded bridge decks did not match the actual intersections of the authored road network and river.
- Bridge decks were visual-only in Godot.

### Changes made
- Added one shared `river_center_x(z)` function for the terrain channel, river water and bridge placement.
- Replaced the four unrelated bridge placements with segment-intersection detection between the road polylines and the sampled river. The current road network produces two bridge decks, each rotated to follow the crossing road, with deck height matched to the road ribbon and rails aligned to the deck.
- Extended the Godot collision traversal to create a static trimesh collision for each `River_Bridge_*` deck while preserving the existing terrain collision.
- Added required runtime-log checks for both bridge collision nodes to the graphical Godot capture workflow.
- Updated project and Blender README documentation.

### Verification status — CI completed
- **Blender generator validation passed** in [run 40099995749](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40099995749): Python syntax, full generation, exactly 64 terrain/water tile exports, 16 POI GLBs, manifest, editable `.blend`, master GLB, and overview PNG. The new placement assertions passed for Bridge 00 at approximately (43.4, -243.9) on road 00 and Bridge 01 at approximately (-30.6, 511.5) on road 02.
- **Godot headless parse/runtime check passed** in [run 40099725480](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40099725480).
- **Graphical Godot capture passed** in [run 40099937163](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40099937163): Blender generated the master GLB, Godot imported it, the log confirmed the terrain collision and both bridge deck collisions, and seven genuine runtime views were captured. No GDScript parse/runtime errors were reported.
- The capture workflow now also packages the full Godot project, generated Blender source/assets, and runtime evidence into one ZIP artifact.

### Remaining manual QA
- The automated run confirms bridge collision creation, but it does not physically drive/walk the player across each bridge. Verify ramp/terrain continuity and collision response in an interactive session.
- Mobile-device performance, seam/transform checks for all 64 tiles in a streamed scene, and final visual fidelity against the concept remain unverified. Heights and POI anchors are art-direction estimates from the manual, not surveyed measurements.

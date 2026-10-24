## 2026-10-24 — Scene audit, player spawn correction, and pipeline documentation

### Reference and dependency audit before editing
- Re-read the production manual pages 3, 5, 7–11, and 20–27: coordinate convention (X/Z with Y height), sixteen estimated POI anchors, 8×8 tile layout, estimated altitude bands, coast/water/river/bridge design, road widths, collision/spawn requirements, and multi-angle runtime QA.
- Inspected `scenes/Main.tscn`, `scripts/world.gd` (all 1,247 lines), `scripts/player.gd`, `project.godot`, `tools/blender/aurora_map_gen.py`, `tools/blender/README.md`, repository instructions, and both Godot workflows.
- Confirmed `Main.tscn` is a `Node3D` with `res://scripts/world.gd`; `world.gd` dynamically attaches `res://scripts/player.gd`. All 27 referenced city archetype scenes exist. The six player input actions (WASD, jump, sprint) are all defined in `project.godot`; the main scene has no scene-level signal connections, and touch buttons connect to existing controller methods in code.
- Audited the latest real capture package from commit `8c3a0bb15dcd6e9d1915c8a35d361b1d881c70e2`: the Godot log confirms the generated Blender master GLB loaded, terrain collision was created, both bridge-deck collisions were created, and all seven view switches completed without GDScript/runtime errors.
- Inspected the seven actual X11 runtime captures. The island/POIs are readable from above, but the current scene remains a stylized blockout, not photorealistic. The player view showed an unhelpful distant horizon and sparse foreground.

### Findings and minimal changes
- The Blender-map spawn was `(300, 35, -242)`, roughly 26 m above the estimated terrain height at that location. The generator height function gives approximately 8.5 m near the station approach; the old spawn explains the poor first-person/third-person framing and unnecessary fall.
- The first correction changed the Blender-map spawn to `(210, 8.8, -180)`; its real runtime screenshot showed the camera too close to the southern station platform. Refined it to `(210, 8.5, -100)`: the generator estimates ~8.17 m ground height there, leaving the player just above the terrain and the camera about 142 m south of the station. The procedural fallback spawn remains unchanged.
- Corrected `README.md`: the assembled Blender master uses a 5 m sampling step, the fallback GDScript terrain uses 28 m, and each exported tile uses a 21×21 sample grid (12.5 m spacing). Documented that the 64 tile GLBs are packaged for future streaming but the current runtime still loads the master GLB.
- No gameplay signals, input actions, scene hierarchy, POI coordinates, or collision-generation logic were changed in this pass.

### Post-change verification
- The first refined commit passed Godot headless validation (`40101092770`) and the real graphical capture/package (`40101092820`). However, the player screenshot still framed the platform too closely, so this second, evidence-led spawn adjustment must pass a new capture before it is accepted. Blender export emits non-fatal missing-Draco-library messages, but the uncompressed GLBs and PNGs were generated and imported successfully.

### Remaining QA
- After CI, inspect the new player capture to ensure the spawn settles onto terrain and the station is framed usefully.
- Manually walk the player across both bridges and test slope/shore collisions; CI verifies collision creation, not physical traversal.
- Tile seams/transforms and runtime streaming are not yet tested because the 64 tile exports are not yet used as separate Godot scenes.
- Android/iOS performance and final visual fidelity against the concept remain unverified; terrain heights and POI anchors are art-direction estimates, not surveyed data.

---

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

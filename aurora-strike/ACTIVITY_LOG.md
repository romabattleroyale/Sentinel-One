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

### Post-change verification — passed on commit `2fd56a9543fe466841e015193177c4012fd94f2f`
- **Godot 4.5.1 headless editor import and short launch passed** in [run 40101597810](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40101597810). This standalone check uses the procedural fallback because the generated master GLB is produced by the graphical pipeline rather than committed as source.
- **Blender-to-Godot graphical runtime capture and package passed** in [run 40101597860](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40101597860). The actual Godot 4.5.1 runtime log confirms `res://world/generated_blender/AURORA_STRIKE_Master_Preview.glb` loaded, the master terrain collision was created, both `River_Bridge_00` and `River_Bridge_01` deck collisions were created, and all seven view changes completed. No GDScript/runtime errors were reported by the capture check.
- Inspected the new real player screenshot: the capsule is grounded on open terrain and Stazione Termini is ahead rather than the camera starting beside the platform. This is a camera/spawn framing improvement, not a full traversal test.
- Verified the generated package contains 64 tile GLBs (62 terrain sectors and 2 sea-only sectors), 16 separate POI GLBs, an 80-row manifest (header plus 64 tile records and 16 POI records), the editable `.blend`, the 12.9 MB master GLB, the overhead PNG, the Godot project, and seven 1280×1280 runtime PNG captures.
- The latest project bundle is artifact [12562154542](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40101597860/artifacts/12562154542); the standalone seven-view evidence is [12562852021](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40101597860/artifacts/12562852021). GitHub retention is through 7 November 2026.
- Blender's log still reports that the optional Draco compression library is missing; this is non-fatal in this runner. GLBs are exported uncompressed, imported by Godot, and included in the passing package.

### Remaining QA
- Manually walk the player across both bridges and test slope/shore collisions, roads, doors and station access; CI verifies collision creation and scene startup, not physical traversal.
- Tile seams/transforms and runtime streaming are not yet tested because the 64 tile exports are not yet used as separate Godot scenes; the runtime currently loads the assembled master GLB.
- Android/iOS performance, target-device texture/LOD behavior, and final visual fidelity against the concept remain unverified. The current scene is still a stylized blockout, not photorealistic. Terrain heights and POI anchors are art-direction estimates, not surveyed data.

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


## 2026-10-24 — Mappa AURORA STRIKE: riallineamento POI e aumento dettaglio procedurale

### Riferimenti e controlli prima della modifica
- Consultato `Manuale_Esecutivo_Mappa_AuroraStrike_Godot.pdf`, in particolare le convenzioni mondo 2000 × 2000 m (pagine 3 e 7) e il registro dei 16 POI (pagina 5).
- Ispezionati `scenes/Main.tscn`, `scripts/world.gd`, `scripts/player.gd`, `project.godot` e `tools/blender/aurora_map_gen.py` prima di intervenire.
- Sono rimasti invariati gli input esistenti e la struttura dei segnali; la modifica Godot è confinata alla costruzione delle etichette di mappa e al distretto residenziale. Le modifiche Blender sono confinate al generatore della mappa.

### Modifiche applicate
- Corrette le coordinate X/Z di tutte le etichette top-down dei POI secondo la tabella del manuale, usando la scala comune della griglia e il centro immagine.
- Aggiunti al quartiere residenziale 36 edifici istanziati da archetipi romani già presenti nel progetto, con variazioni di scala e rotazione, più rete locale di carreggiate e marciapiedi. Il blockout residenziale duplicato nel GLB master è escluso per evitare doppioni.
- Aggiunte variazioni di rilievo a media frequenza, attenuate nelle zone urbane; distribuzione più ampia e variata di alberi con esclusioni per lago, letto del fiume e POI urbani; introdotte strisce centrali stradali che seguono il tracciato e il terreno. La geometria procedurale resta stilizzata: questo non equivale ancora a fotorealismo.

### Verifiche automatizzate
- **Blender generator validation — superata**, commit del codice `984342a2bc25c5d771efd5f8f7bb535c59588575`: sintassi Python, generazione della mappa, export GLB e controlli sui tile/POI del workflow. [Run](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40113682026)
- **Godot 4.5.1 headless import e avvio — superati**, medesimo commit. [Run](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40113681965)
- **Cattura grafica Godot e ZIP — in corso al momento di questo aggiornamento**. Non considerare una schermata precedente come prova runtime delle modifiche correnti; aggiungere il riferimento del run finale dopo il completamento. [Run](https://github.com/romabattleroyale/Sentinel-One/actions/runs/40113681963)

### Cosa resta da verificare
- Ispezione visiva delle nuove schermate runtime dopo la generazione della mappa aggiornata.
- Collisioni e percorribilità a piedi/veicolo di ponti, rive, strade e nuovi edifici; i test automatici controllano parsing, generazione e avvio ma non sostituiscono un playtest interattivo.
- Verifica di prestazioni su dispositivo Android/iOS, giunzioni di tutti i tile in streaming, materiali PBR e qualità finale contro la tavola concept. La mappa consegnata in questo checkpoint è un avanzamento procedurale, non ancora una ricostruzione fotorealistica completa.

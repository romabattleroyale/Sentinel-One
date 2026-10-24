# AURORA STRIKE — Nuova Aurora

Progetto Godot 4.5.1+, GDScript, renderer Mobile, pensato per Android e iOS. La mappa-obiettivo è un'isola di 2000 × 2000 metri.

## Build attuale
- Costa irregolare con oceano profondo, fascia di bassi fondali turchesi e spiagge con colori legati ai biomi.
- Terreno generato con campionamento a 5 m e colori di bioma sfumati: neve a nord-ovest, bosco ombra, colline verdi, zona agricola, cava sabbiosa e deserto rosso; la griglia più fitta e le normali smussate riducono sagome a gradini e faccettature senza spostare gli ancoraggi POI.
- Lago Azzurro e corso d'acqua turchese, alberature aggiuntive nel bosco settentrionale e rilievi secondari nelle zone verdi e desertiche.
- Rete stradale, marciapiedi più sottili, collegamenti verso porto, montagna, riviera, base militare, cava e deserto.
- Città più densa con lotti allineati alla viabilità e 27 scene archetipiche romane già presenti nel repository, con materiali e texture importati.
- Stazione Termini allineata al POI Blender con atrio, insegna 3D, pensiline, piattaforme, rotaie e traverse; il centro città usa 24 archetipi romani dettagliati già presenti nel progetto e il centro commerciale usa i sei edifici vetrati runtime. Porto con moli/container, fabbrica, serbatoi, pista e hangar militari, campi e silos.
- Controller per movimento, salto e corsa; joystick touch, pulsanti per salto/corsa e controllo telecamera su smartphone.
- Atlante dall'alto con griglia A–J / 1–10, nomi POI, titolo, bussola e scala.

## Avvio e viste
Aprire questa cartella in Godot 4.5.1 o successivo e premere F5. Desktop: WASD, Space, Shift e mouse per guardare. I tasti 1–7 selezionano: atlante, personaggio, stazione, area industriale, costa, centro città e montagne nevose.

## Verifica
Le GitHub Actions `AURORA STRIKE runtime check` e `AURORA STRIKE graphical runtime capture` verificano importazione, parsing e avvio. La cattura multi-vista acquisisce immagini dal runtime reale e controlla i log e la dimensione dei PNG; uno screenshot non viene accettato se la scena non segnala `AURORA_RUNTIME_READY`.

## Limiti conosciuti
Questa è una build giocabile in evoluzione, non ancora una replica fotorealistica della reference. Il terreno ha biomi procedurali e rilievi semplificati, e parte degli edifici è modulare/procedurale; le sagome naturali, i POI esplorabili interni, la varietà dei dettagli e il livello artistico richiedono ancora lavoro. I risultati runtime vanno valutati separando i test tecnici dalla fedeltà estetica finale.


## Blender map pipeline

The offline authoring pipeline is in `tools/blender/`. Run `aurora_map_gen.py` in Blender 3.6+ or 4.x to generate the estimated 2000 × 2000 m island, tile GLBs, modular POI GLBs, editable Blender source, overview PNG and CSV manifest. The generator follows the coordinate convention and sixteen approximate POI anchors from pages 3 and 5 of the production manual. Page 8 altitude bands and all intermediate terrain boundaries are art-direction estimates.

When `world/generated_blender/AURORA_STRIKE_Master_Preview.glb` is present, Godot loads it and adds a static terrain collision mesh. The master omits the primitive blockouts for Città Centrale, Stazione Termini, Centro Commerciale and Zona Industriale; the Blender-map runtime path replaces them with the repository's detailed Roman building scenes, the six-tower commercial builder, the station builder anchored at (195, -242), and a detailed industrial complex with collision-enabled tanks, access ladders, roof vents, a pipe rack and pump skids anchored at (31, 70). If the GLB is absent, Godot retains the existing procedural fallback. The graphical runtime workflow builds the Blender master first and captures multiple real camera views from Godot.

## Blender map source pipeline

The executable generator is `tools/blender/aurora_map_gen.py`. It uses Blender's built-in `bpy` API and standard Python only. It follows the approximate X/Z POI anchors from the map manual, builds an island/terrain, coastal water, road links, rivers and bridges, with differentiated scene geometry for all 16 regions.

Run with Blender 3.6+:

```bash
AURORA_OUTPUT_DIR=/path/to/output blender --background --python tools/blender/aurora_map_gen.py
```

Expected outputs:
- `AURORA_STRIKE_Map_Source.blend`: editable Blender source scene.
- `AURORA_STRIKE_Master_Preview.glb`: full scene used by the Godot prototype when present.
- `tiles/Tile_X00_Z00.glb ... Tile_X07_Z07.glb`: 64 terrain tile exports. Each tile stores its terrain mesh in tile-local X/Z coordinates on a 5 m lattice and records `world_origin_x/world_origin_z` attributes; shared-edge samples are generated from the same global coordinates to minimize seams. Place each tile at that world origin in Godot.
- `poi/*.glb`: 16 modular POI exports, centered around their listed anchor.
- `preview/aurora_strike_overview.png`: overhead rendered preview.
- `manifest.csv`: tile origins, world bounds, POI anchors and procedural provenance.

The manual explicitly marks coordinates, widths and altitudes as estimates derived from the illustrated concept, not survey data. Check tile transforms and the preview in Godot before using the tiles for runtime streaming. The CI workflow runs Blender with a software OpenGL/Xvfb environment, then Godot imports the master GLB and captures multiple views.

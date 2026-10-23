# AURORA STRIKE — Nuova Aurora

Progetto Godot 4.5.1+, GDScript, renderer Mobile, pensato per Android e iOS. La mappa-obiettivo è un'isola di 2000 × 2000 metri.

## Build attuale
- Costa irregolare con oceano profondo, fascia di bassi fondali turchesi e spiagge con colori legati ai biomi.
- Terreno generato con griglia densa e colori di bioma sfumati: neve a nord-ovest, bosco ombra, colline verdi, zona agricola, cava sabbiosa e deserto rosso.
- Lago Azzurro e corso d'acqua turchese, alberature aggiuntive nel bosco settentrionale e rilievi secondari nelle zone verdi e desertiche.
- Rete stradale, marciapiedi più sottili, collegamenti verso porto, montagna, riviera, base militare, cava e deserto.
- Città più densa con lotti allineati alla viabilità e 27 scene archetipiche romane già presenti nel repository, con materiali e texture importati.
- Stazione Termini con atrio, insegna 3D, pensiline dei binari, piattaforme, rotaie e traverse; porto con moli/container, fabbrica, serbatoi, pista e hangar militari, campi e silos.
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

When `world/generated_blender/AURORA_STRIKE_Master_Preview.glb` is present, Godot loads it and adds a static terrain collision mesh; if the file is absent, Godot retains the existing procedural fallback. The graphical runtime workflow builds the Blender master first and then captures multiple camera views from Godot.

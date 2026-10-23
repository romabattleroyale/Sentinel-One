# AURORA STRIKE — Nuova Aurora

Progetto Godot 4.5.1+, GDScript, renderer Mobile, pensato per Android e iOS. La mappa di riferimento è un'isola di 2000 × 2000 metri.

## Cosa c'è nella build
- Landmass irregolare con mare e fascia d'acqua bassa turchese, spiagge differenziate per bioma.
- Biomi principali: Monte Nevoso, Lago Azzurro, Bosco Ombra, Isole del Relitto, Porto, Città Centrale, Stazione Termini, Quartiere Residenziale, Colline Verdi, Riviera, Base Militare, Zona Industriale, Centro Commerciale, Zona Agricola, Cava Desolata e Deserto Rosso.
- Strade urbane e connessioni stradali verso le aree periferiche.
- Edifici romani dettagliati importati dalla libreria del repository: 27 scene archetipiche con materiali e texture, usate al posto di gran parte dei blocchi procedurali.
- Stazione centrale, porto con moli e container, campi e silos, impianto industriale, hangar e pista militare.
- Controller di movimento, salto, corsa e controlli touch; telecamera modificabile durante il runtime.
- Vista atlante dall'alto con griglia A–J / 1–10, nomi dei POI, titolo, bussola e scala.

## Avvio e controlli
Aprire questa cartella in Godot 4.5.1 o successivo e premere F5. Desktop: WASD, Space, Shift e mouse per guardare. I tasti 1–5 selezionano la panoramica dall'alto, personaggio, stazione, area industriale e costa.

## Verifica
Le GitHub Actions AURORA STRIKE runtime check e AURORA STRIKE graphical runtime capture controllano l'importazione, il parsing degli script, l'avvio della scena e le catture grafiche. Il workflow multi-vista deve acquisire cinque screenshot distinti; i file sono accettati soltanto se esistono, superano una dimensione minima e i log non contengono errori.

## Limiti attuali
Questa è una build giocabile in evoluzione, non ancora una replica fotorealistica della reference. L'architettura è in parte procedurale, la morfologia del terreno e i dettagli naturali devono ancora essere portati a un livello artistico molto più ricco e vanno aggiunti POI esplorabili interni. Le immagini di runtime vanno valutate rispetto a questi limiti, senza confondere il test tecnico con la fedeltà visiva finale.

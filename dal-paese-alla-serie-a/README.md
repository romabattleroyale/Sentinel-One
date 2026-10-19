# Dal Paese alla Serie A
Progetto Godot 4.7 per il manager calcistico mobile/desktop.

## Aprire il progetto
1. Apri la cartella `dal-paese-alla-serie-a` in Godot 4.7.
2. Apri `project.godot` ed esegui con F6/F5.

## Contenuto attuale
- Schermata di creazione del club.
- Dashboard responsive con indicatori, menu a schede e prossima partita.
- Rosa generata, simulazione del risultato, budget, tifosi e morale.
- Schermate base per rosa, classifica, tattiche, mercato e dirigenza.
- Salvataggio JSON in `user://career_save.json`.

## Verifica automatica
Il workflow GitHub Actions scarica Godot headless sul runner Linux e controlla l'importazione/parse del progetto. Il runtime Android va comunque provato sul dispositivo reale.

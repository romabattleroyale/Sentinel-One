# AURORA STRIKE — Blender map generation tools

This folder contains the offline Blender authoring pipeline for the island map specified in the supplied production manual.

- `aurora_map_gen.py`: complete source generator.
- `poi_coordinates.csv`: the 16 estimated POI anchor coordinates from manual page 5.
- `README.md`: usage, export conventions, coordinate system, and cautions.

Target: Blender 3.6+ / 4.x. 1 unit = 1 metre. X-/X+ west/east; Z-/Z+ north/south. The generator creates real geometry, a 2000×2000 m island, water/coast, biomes, district blockouts, 64 terrain tiles of 250 m, modular POI exports, an overview PNG, and a manifest. All altitudes and landform edges are concept-derived estimates, not measured survey data. Import and seam-check each tile in Godot before gameplay use.
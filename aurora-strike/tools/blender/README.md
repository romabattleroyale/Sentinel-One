# AURORA STRIKE — Blender/Python map pipeline

## Files
- `aurora_map_gen.py`: procedural Blender scene generator and export pipeline.
- `poi_coordinates.csv`: sixteen estimated POI anchors from page 5 of the production manual.

## Run
Use Blender 3.6+ / 4.x. Open the Python file in the Scripting workspace and run it, or from a shell run `blender --background --python aurora_map_gen.py`. Output defaults to a `generated` directory beside the script; set `AURORA_OUTPUT_DIR` to override.

## Coordinate convention
1 Blender unit = 1 m. Horizontal axes are X/Z: negative X west, positive X east, negative Z north, positive Z south. Island target is 2000 × 2000 m. The world is split into 8 × 8 tiles of 250 m; tile (i,j) origin is X=-1000+250×i, Z=-1000+250×j.

## Generated assets
The pipeline creates editable Blender source, a top-down overview PNG, terrain tile GLBs, separate POI module GLBs, an assembled preview GLB and a CSV manifest with bounds/origins/provenance.

## Important
The manual's page 5 POI coordinates and page 8 altitudes are estimates inferred from an illustration, not a measured 3D world. The generated terrain and district shapes remain an art-directed blockout. Validate seams, GLB transforms, slopes, collisions and mobile performance in Godot before using all tiles in the game. Blender owns static geometry; existing Godot scripts remain responsible for runtime gameplay and controls. No third-party assets are bundled.
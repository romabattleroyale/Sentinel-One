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
## River and bridge validation

The terrain valley and visible river use the same `river_center_x(z)` function. Bridge decks are generated only at actual intersections between the river polyline and the authored road polylines; each deck is aligned to its road tangent and its top is matched to the road ribbon height. The Godot importer creates a static trimesh collision for the master terrain and for each `River_Bridge_*` deck. The graphical CI run checks that both current bridge collision nodes are present in the real runtime log. This validates scene generation and collision creation, not yet a manual traversal test on a target phone.


## Reference-map iteration — 24 October 2026
The generator now builds a linked 12-route road network with Catmull–Rom sampling, including western/central links, the north lake/forest link, a residential/commerce route, a southern coast route and a quarry access loop. Road-river crossing validation now permits multiple real intersections and checks the main transport spine and southern quarry route. The height field adds overlapping ridge masses in Monte Nevoso, a lowered quarry bowl with a raised rim, southern mesa relief, and multi-frequency surface variation softened around urban areas. Shore bands vary by coastal biome. Central-city and residential POIs have more façade/window/shop detail; woodland batches are denser and cover additional forest pockets. The overview render enables higher samples and ambient occlusion where supported.

This is a structural/detail pass toward the supplied reference, **not a claim of photorealistic completion**. The current output remains procedurally modeled/stylized. Still required: richer asset-level architecture for all 16 POIs, PBR texture sets, shoreline foam/waves, urban prop clutter, runtime comparison at ground level, mobile performance tests, tile-streaming seam checks and interactive bridge/collision playtests.

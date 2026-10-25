# AURORA STRIKE — Godot mobile terrain prototype

This is an **early runnable prototype**, added because the main repository currently contains the Blender map generator but no Godot project.

## Open it
1. Download this folder or the repository branch as a ZIP.
2. Open Godot 4.5+ and choose **Import**.
3. Select `project.godot` inside `aurora-strike/godot-prototype/`.
4. Run `scenes/Main.tscn`.

## Current prototype contents
- Procedural 2 km island terrain with snow/alpine, forest, green hills, quarry and red-desert colour zones.
- Basic ocean plane and Lago Azzurro surface.
- 16 named POI markers placed using the map generator's coordinate registry.
- Simple road links between key areas.
- CharacterBody3D player with collision, camera, virtual left joystick, right-side swipe look and jump button.
- Mobile renderer configuration.

## Important limitations
This is a **playable integration scaffold, not the final image-matching map**. The terrain uses procedural vertex colours, not the baked 128 px terrain textures in the Blender exporter; POIs are representative markers rather than final detailed structures; roads and shoreline are simplified. No successful Godot runtime test has been claimed because a Godot executable is not available in the editing environment. Run it in Godot and fix any import/runtime errors before treating it as verified.

## Fast map asset generation
Set `AURORA_FAST_PREVIEW=1` in the environment before running `tools/blender/aurora_map_gen.py` to skip the expensive 1600×1600 overview render and master preview GLB while still exporting tile and POI GLBs. This reduces iteration cost; it does not guarantee a specific runtime duration.

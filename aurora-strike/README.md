# AURORA STRIKE — Godot CI setup

This folder is reserved for the AURORA STRIKE Godot project. The existing repository began as the legacy Sentinel-One Android application; its existing files are intentionally preserved on this branch.

## Add the game project

Upload the contents of the AURORA STRIKE Godot project into `aurora-strike/`, so that this file exists:

`aurora-strike/project.godot`

Keep the original `.gd`, `.tscn`, `.tres`, assets and scenes. Do not upload the editor cache folder `.godot/`.

## Build and validation

The workflow `.github/workflows/aurora-strike-godot.yml` downloads Godot 4.7.2 on a GitHub-hosted Linux runner, imports the project, performs a headless editor/runtime check, and uploads logs and a source snapshot as a workflow artifact. If a Linux export preset exists, it also attempts to export a Linux executable.

A successful headless check is not a replacement for visual inspection on the Android device. Screenshot capture needs a display-enabled rendering setup or a dedicated render/test scene; the standard headless run may not provide screenshots.

Open the repository's **Actions** tab and run **AURORA STRIKE — Godot Linux build** after uploading the project. Download the artifact from the workflow run to inspect the logs and output.

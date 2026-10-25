#!/usr/bin/env bash
set -euo pipefail

# Install Godotite into the AURORA STRIKE Godot project.
# Requirements: curl, unzip, Godot 4.5+ .NET editor, .NET 8 SDK.
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDONS="$PROJECT/addons"
DEST="$ADDONS/godotite"
VERSION="v0.9.0"
URL="https://github.com/Arkaein/godotite/archive/refs/tags/${VERSION}.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ -d "$DEST" ]]; then
  echo "Godotite already exists at $DEST; refusing to overwrite it."
  exit 2
fi
mkdir -p "$ADDONS"
echo "Downloading Godotite ${VERSION}..."
curl --fail --location --retry 3 "$URL" --output "$TMP/godotite.zip"
unzip -q "$TMP/godotite.zip" -d "$TMP/unpacked"
SOURCE="$TMP/unpacked/godotite-${VERSION#v}/addons/godotite"
if [[ ! -f "$SOURCE/plugin.cfg" ]]; then
  # GitHub archive folder names can vary; locate the actual plugin directory.
  SOURCE="$(find "$TMP/unpacked" -path '*/addons/godotite/plugin.cfg' -print -quit | xargs -r dirname)"
fi
if [[ -z "${SOURCE:-}" || ! -f "$SOURCE/plugin.cfg" ]]; then
  echo "Could not find addons/godotite/plugin.cfg in the downloaded archive." >&2
  exit 3
fi
cp -a "$SOURCE" "$DEST"
# Godotite's editor-time mesh builder is C#. Copy its matching SDK project too.
CSPROJ="$(find "$TMP/unpacked" -maxdepth 3 -name 'Godotite.csproj' -print -quit)"
if [[ -z "$CSPROJ" || ! -f "$CSPROJ" ]]; then
  echo "Could not find Godotite.csproj in the downloaded archive." >&2
  rm -rf "$DEST"
  exit 4
fi
if [[ -e "$PROJECT/Godotite.csproj" ]]; then
  echo "Godotite.csproj already exists; refusing to overwrite it." >&2
  rm -rf "$DEST"
  exit 5
fi
cp "$CSPROJ" "$PROJECT/Godotite.csproj"
echo "Installed Godotite into $DEST and copied Godotite.csproj."
echo "Build once with: dotnet build Godotite.csproj"
echo "Then enable Project Settings > Plugins > Godotite and build the terrain LOD in the editor."

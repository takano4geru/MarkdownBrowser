#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-macos}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"

version_name() {
  sed -n 's/^version: \([^+[:space:]]*\).*/\1/p' "$ROOT_DIR/pubspec.yaml"
}

build_macos_unsigned_zip() {
  local version
  local app_path
  local artifact_name
  local artifact_path

  version="$(version_name)"
  if [[ -z "$version" ]]; then
    echo "Could not read version from pubspec.yaml" >&2
    exit 1
  fi

  echo "Building unsigned macOS release..."
  (cd "$ROOT_DIR" && flutter build macos --release)

  app_path="$ROOT_DIR/build/macos/Build/Products/Release/markdown_browser.app"
  if [[ ! -d "$app_path" ]]; then
    echo "Expected app bundle was not found: $app_path" >&2
    exit 1
  fi

  mkdir -p "$DIST_DIR"
  artifact_name="markdown_browser-macos-v${version}-unsigned.zip"
  artifact_path="$DIST_DIR/$artifact_name"

  echo "Packaging $artifact_name..."
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$artifact_path"

  echo
  echo "Created: $artifact_path"
  echo "Note: this artifact is unsigned and not notarized. macOS Gatekeeper will warn users."
}

case "$TARGET" in
  macos)
    build_macos_unsigned_zip
    ;;
  *)
    echo "Usage: ./deploy.sh [macos]" >&2
    echo "Currently supported targets: macos" >&2
    exit 2
    ;;
esac

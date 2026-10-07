#!/bin/bash
# Builds Sustain from this checkout and installs it in /Applications.
# The build number is the commit count, so "Sustain 0.3.0 (57)" in Settings always maps back to one commit.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -n "$(git status --porcelain)" ]; then
  echo "Uncommitted changes. Commit or stash them first, so the build number points at real code." >&2
  exit 1
fi

build=$(git rev-list --count HEAD)
branch=$(git rev-parse --abbrev-ref HEAD)
commit=$(git rev-parse --short HEAD)

xcodegen generate
xcodebuild -quiet -project Sustain.xcodeproj -scheme Sustain -configuration Release \
  -derivedDataPath build CURRENT_PROJECT_VERSION="$build" build

if pgrep -x Sustain >/dev/null; then
  osascript -e 'quit app "Sustain"'
  sleep 2
fi
rm -rf /Applications/Sustain.app
cp -R build/Build/Products/Release/Sustain.app /Applications/

version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" /Applications/Sustain.app/Contents/Info.plist)
echo "Installed Sustain $version ($build) from $branch at $commit."
if [ "$branch" != "main" ]; then
  echo "Not main: fine for trying a branch, but merge it before calling it a release."
elif [ -z "$(git tag --points-at HEAD)" ]; then
  echo "Untagged. If this is a release: git tag v$version && git push origin v$version"
fi

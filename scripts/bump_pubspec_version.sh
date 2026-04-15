#!/usr/bin/env bash
set -euo pipefail

BUMP_TYPE="${1:-patch}"

if [[ ! "${BUMP_TYPE}" =~ ^(major|minor|patch)$ ]]; then
  echo "Invalid bump type: ${BUMP_TYPE}. Use major, minor, or patch."
  exit 1
fi

CURRENT_LINE="$(grep -E '^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' pubspec.yaml | head -n 1 || true)"

if [[ -z "${CURRENT_LINE}" ]]; then
  echo "Could not find a valid version line in pubspec.yaml"
  exit 1
fi

CURRENT_VERSION="$(echo "${CURRENT_LINE}" | awk '{print $2}')"

if [[ "${CURRENT_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  BUILD="${BASH_REMATCH[4]}"
else
  echo "Invalid version format in pubspec.yaml: ${CURRENT_VERSION}"
  exit 1
fi

case "${BUMP_TYPE}" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

BUILD=$((BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD}"

sed -E -i "0,/^version:[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+/s//version: ${NEW_VERSION}/" pubspec.yaml

echo "Version bumped: ${CURRENT_VERSION} -> ${NEW_VERSION}"

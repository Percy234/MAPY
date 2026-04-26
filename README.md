# mapy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web Data Persistence In Dev

If you run Flutter Web with default `flutter run -d chrome`, local data can appear to disappear between runs because:

- The debug browser profile may be temporary.
- The localhost port can change, and browser storage is scoped by origin (`scheme + host + port`).

This workspace includes VS Code launch configs in `.vscode/launch.json`:

- `MAPY Web (Chrome Persistent)`: fixed port + fixed Chrome user data directory.
- `MAPY Web (Web Server Persistent)`: run a fixed web server and open URL in your normal browser profile.

If you test persistence, use one browser and one origin consistently (for example `http://localhost:7357`).
Different browsers (Chrome/Edge/Firefox) do not share local storage data.

## Automated Release Versioning (GitHub Flow)

This repository supports auto version bump on release PR merge to `main`.

### How it works

- Add one release label to your PR before merge:
	- `release:patch` -> bump `x.y.z` to `x.y.(z+1)`
	- `release:minor` -> bump `x.y.z` to `x.(y+1).0`
	- `release:major` -> bump `x.y.z` to `(x+1).0.0`
- Build number (`+n`) in `pubspec.yaml` is always incremented by `+1`.
- After merge, workflow will:
	- update `version:` in `pubspec.yaml`
	- build Android release APK
	- commit change to `main`
	- create and push Git tag `v<app_version>`
	- publish a GitHub Release with generated notes
	- attach APK in Release Assets with filename format: `mapy-v<app_version>-build<build_number>.apk`

### Files

- Workflow: `.github/workflows/release-auto-version.yml`
- Version bump script: `scripts/bump_pubspec_version.sh`


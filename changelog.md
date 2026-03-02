# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Premium `README.md` with modern design and clear documentation.
- Adhan tracking history view to diagnose playback issues.
- Detailed logging for Adhan playback lifecycle (Scheduled, Triggered, Playing, Success, Error).
- Per-day prayer notification overrides with sync logic.
- Live Activities for prayer time display on Dynamic Island and Lock Screen.
- User-controlled performance logging.

### Fixed

- Crash in "Copy Logs" functionality.

### Performance

- Improved `UserDefaults` write efficiency and debounced log saves.
- Debounced location updates and throttled notification scheduling.
- Cached audio durations.

---
*Generated based on git history on 2026-03-01.*

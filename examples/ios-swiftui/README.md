# Example - iOS (SwiftUI)

A minimal tapwright config for a SwiftUI app driven on the iOS Simulator (macOS only).

## Setup

```bash
# One-time: idb
brew tap facebook/fb && brew install idb-companion
pip3 install fb-idb

cd /path/to/your-ios-app
/path/to/tapwright/install.sh
cp /path/to/tapwright/examples/ios-swiftui/tapwright.config.yml ./tapwright.config.yml
export TAPWRIGHT_QA_PASSWORD='...'
```

Adjust `scheme`, the `.xcodeproj` name in `build`, and `bundle_id`.

## Try `/exec`

Visible simulator (default - you can watch it):
```
/exec on ios: log in and open settings
```

Fast/background:
```
/exec on ios headless: open settings and toggle notifications off
```

The agent builds via `xcodebuild`, finds the `.app` under `build/DerivedData`, installs and
launches it on a booted simulator, starts `idb companion`, then dumps the accessibility tree
(`idb ui describe-all`) and taps `AXLabel` frames.

## Try `/test`

```
/test settings --ios
/test settings --ios --headless
```

Report + DSL land under `specs/settings/runs/ios/<run_id>/`.

## Notes

- Default is a **visible** simulator; add `--headless` for CI-style speed.
- If `idb ui` says connection refused, run `idb companion --udid <UDID> &` and retry.
- Prefer reusing an existing DerivedData `.app` to skip a full rebuild between runs.

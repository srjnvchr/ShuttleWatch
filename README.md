# Badminton Tracker

An iPhone and Apple Watch app that scores my badminton games live.

The iPhone records the court from a tripod and detects rallies from video. The Watch shows the score and buzzes on each point. When the app is unsure who won a rally, I confirm it with one tap on the Watch.

This is a personal project. It is not intended for the App Store.

## Status

Planning. See [ROADMAP.md](ROADMAP.md) for product requirements, decisions, and phases.

## How it works

| Part | Role |
| --- | --- |
| **iPhone** | Sits on a tripod behind a baseline, raised. Records at 60 fps, runs vision models on-device, and owns the match state. |
| **Apple Watch** | Shows the score, buzzes on each point, and handles confirm, undo, and override. Runs a workout session for heart rate. |
| **Live Activity** | Shows the live score on the Lock Screen, Dynamic Island, and Watch Smart Stack. |

The scoring pipeline runs in five stages on the iPhone:

1. **Court calibration.** Tap the four court corners to map pixels to court coordinates.
2. **Shuttle tracking.** A TrackNet-style Core ML model finds the shuttle in each frame.
3. **Player detection.** Vision body pose locates the players.
4. **Rally state machine.** Detects serve, rally, and shuttle dead.
5. **Rules engine.** Turns a rally result into the correct score, server, and service court.

## Repository layout

```
.
├── ios/                         Xcode project
│   ├── BadmintonTracker/        iPhone app
│   ├── BadmintonTrackerWatch/   Watch app
│   ├── BadmintonTrackerWidgets/ Live Activity extension
│   └── Packages/
│       └── ScoringKit/          Rules engine (shared Swift package)
├── ml/                          Python: labelling, training, Core ML export
│   ├── data/                    Footage and labels (never committed)
│   ├── notebooks/
│   └── scripts/
├── CLAUDE.md                    Project context for Claude Code
├── ROADMAP.md
└── README.md
```

`ScoringKit` holds all badminton rules with no UI code. The iPhone and Watch apps both depend on it, and it is tested on its own with `swift test`.

## Tech stack

- **Apps:** Swift and SwiftUI for iPhone, Watch, and the Live Activity.
- **Video and ML:** AVFoundation for capture, Vision and Core ML for inference.
- **Data and sync:** WatchConnectivity, SwiftData, and HealthKit.
- **Training:** Python, PyTorch, and coremltools.

## Getting started

### Requirements

- A Mac with the latest Xcode
- An iPhone and Apple Watch on current OS versions
- A paid Apple Developer Program membership
- A recent Python 3 for the `ml/` folder

### iOS and watchOS apps

1. Open `ios/BadmintonTracker.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, set your team for each target.
3. Select your iPhone as the run destination and run. The Watch app installs through the paired iPhone.

Run the rules engine tests:

```sh
cd ios/Packages/ScoringKit
swift test
```

### ML pipeline

```sh
cd ml
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Put match footage and labels in `ml/data/`. This folder is gitignored.

## Privacy

Match footage stays on the phone and in `ml/data/`. It is never committed or uploaded.

## Working with Claude Code

`CLAUDE.md` holds shared project context and is committed. Personal Claude settings such as `CLAUDE.local.md` and `.claude/settings.local.json` stay local and are gitignored.

## License

Personal project. All rights reserved.

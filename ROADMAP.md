# Badminton Tracker: Product Requirements and Roadmap

As of 30 October 2026.

## 1. Summary

An iPhone and Apple Watch app that scores singles and doubles badminton live. The iPhone detects rallies from video. The Watch confirms uncertain points with one tap.

The hardest part is not the app. It is turning video into "who won that rally." The roadmap is built around testing that early, while shipping a useful manual scorer first.

## 2. Goals and non-goals

**Goals**

- Score singles and doubles matches with correct server and service court on every point.
- Detect rally start and end automatically from a single iPhone camera.
- Award obvious points automatically. Ask on the Watch when unsure.
- Run fully on-device at my usual venue.

**Non-goals for v1**

- App Store release.
- Reliable close line calls.
- Multiple cameras.
- Spectator score sharing.
- Android or any non-Apple platform.

## 3. Decisions

| Question | Decision | What it changes |
| --- | --- | --- |
| Match types | Singles and doubles in v1 | Rules engine handles doubles service rotation from day one. Vision must track four players, so doubles will need the Watch confirm more often. |
| Camera | Tripod behind a baseline, elevated | Good view of landing side and depth. The far-side shuttle is small and the near player can block it. |
| Automation level | One-tap Watch confirm is acceptable | Phase 3 (semi-automatic) is the real target. Phase 4 is optional polish. |
| Distribution | Personal use only | No App Store review, privacy policy, or onboarding polish. |
| Tooling | MacBook with Xcode, Claude Code, paid developer account | Full Xcode workflow: Watch app, simulator, debugger, and Instruments are all available. |
| Experience | New to Swift | Learn Swift basics during Phase 0, while the Python feasibility work runs. |

## 4. The core problem

To score a rally automatically, the system must answer four questions:

1. **When did the rally start?** (the serve)
2. **When did it end?** (the shuttle hits the floor or the net)
3. **Who hit last, and which side did it land on?**
4. **Was it in or out?**

Questions 1 and 2 are very achievable. Question 3 is achievable once the court is calibrated. Question 4 is unreliable from one camera, so the Watch confirm covers it.

## 5. System overview

| Part | Responsibilities |
| --- | --- |
| **iPhone** | Camera capture, vision pipeline, rally state machine, rules engine, match storage. The single source of truth for match state. |
| **Apple Watch** | Score display, haptic per point, confirm, undo, override, manual scoring, workout session. Never decides points on its own. |
| **Live Activity** | Live score on the Lock Screen, Dynamic Island, and Watch Smart Stack. Replaces a home screen widget, which cannot refresh fast enough. |

### Vision pipeline

1. **Court calibration.** Tap the four court corners at setup. This produces a homography from pixels to court coordinates.
2. **Shuttle tracking.** A TrackNet-style model reads three consecutive frames and outputs the shuttle position. Trained in Python, converted with coremltools. Apple's built-in trajectory detection is worth a quick test, but shuttles decelerate sharply and may not fit its arc model.
3. **Player detection.** Vision body pose locates players, helps identify the hitter, and spots the serve stance.
4. **Rally state machine.** See section 8.
5. **Rules engine.** `ScoringKit`, see section 6.1.

### Tracking overlay

A visual layer drawn on top of video, so tracking can be checked by eye. Used offline in Phase 0 (FR-26), live in Phase 3 (FR-27), and on replays in Phase 5 (FR-28).

- **Shuttle:** a circle around the shuttle, plus a short trail of its last few positions (about 8 to 10 frames, roughly 0.15 seconds at 60 fps).
- **Players:** a halo drawn flat on the floor under each player. Its center is the midpoint between the two ankles from body pose.
    - With court calibration, the center is mapped to court coordinates, a circle of fixed real size (for example 0.5 m across) is drawn there, and it is mapped back to the image. The halo then follows the court's perspective.
    - Without calibration (Phase 0), a flattened ellipse is used instead.
    - When a player jumps, the halo stays on the floor at the last position where the feet were on the ground, until the player lands.
    - If one ankle is hidden, use the visible one. If both are hidden, keep the last known position for a few frames instead of flickering.

## 6. Functional requirements

Priority: **Must** = needed for that phase to be useful. **Should** = core to automation. **Could** = later.

| ID | Requirement | Priority | Phase |
| --- | --- | --- | --- |
| FR-01 | Create a match: singles or doubles, player or team names, first server, starting ends. In doubles, also ask for the first server and first receiver before each game. | Must | 1 |
| FR-02 | Rules engine implementing the scoring rules in 6.1. | Must | 1 |
| FR-03 | Configurable format: points per game, point cap, and games per match (1 or best of 3, default 1). | Must | 1 |
| FR-04 | Manual scoring on iPhone. | Must | 1 |
| FR-05 | Manual scoring on Watch. Remains as a fallback in every phase. | Must | 1 |
| FR-06 | Undo, back to the start of the match. | Must | 1 |
| FR-07 | iPhone and Watch stay in sync. The iPhone is authoritative. Watch taps queue if briefly disconnected. | Must | 1 |
| FR-08 | Live Activity showing score, games, and server. | Must | 1 |
| FR-09 | Match history with a per-rally log. | Must | 1 |
| FR-10 | Workout session on the Watch for heart rate and calories. | Should | 1 |
| FR-11 | Record 60 fps video during a match, with each rally's timestamps from manual scoring. | Should | 2 |
| FR-12 | Export a match's video and rally labels for the ML pipeline. | Should | 2 |
| FR-13 | Court calibration by tapping four corners. | Should | 2 |
| FR-14 | Mask everything outside my court. | Should | 3 |
| FR-15 | Live rally start and end detection. | Should | 3 |
| FR-16 | Watch prompt at rally end to confirm the winner. | Should | 3 |
| FR-17 | Track which player or team is on which end, across changes of ends. | Should | 3 |
| FR-18 | Automatic point award above a confidence threshold. Below it, fall back to FR-16. | Could | 4 |
| FR-19 | Stats: rally length, shot count, longest rally. | Could | 5 |
| FR-20 | Highlight clip per rally. | Could | 5 |
| FR-21 | Heart rate per rally. | Could | 5 |
| FR-22 | Swing count from Watch motion data. | Could | 5 |
| FR-23 | Shot placement heatmap. | Could | 5 |
| FR-24 | Home screen widget showing the last match. | Could | 5 |
| FR-25 | Spectator score sharing (needs a server). | Could | 5 |
| FR-26 | Write a video with the tracking overlay drawn on recorded footage, to check tracking quality by eye. | Should | 0 |
| FR-27 | Optional live tracking overlay on the camera preview, for setup and debugging. | Should | 3 |
| FR-28 | Tracking overlay on replays and highlight clips. | Could | 5 |
| FR-29 | Camera view: a button on the scoring screen switches to the live back camera preview with each side's score on top, and a button there switches back. View only, nothing is recorded. Follows the phone's orientation. | Should | 1 |

### 6.1 Scoring rules

Based on the BWF Laws of Badminton, adapted for casual play. The format values are configurable (FR-03) in case the official scoring format changes.

- Rally point scoring. Every rally wins a point.
- A game is won at 21 points.
- At 20-all, a side must lead by 2 to win.
- At 29-all, the next point wins the game (cap of 30).
- A match is either 1 game or best of 3 games, chosen when the match is created. New matches default to 1 game.
- The winner of a game serves first in the next game.

**Reminders.** Intervals and end changes are reminders only. The players can skip them, and scoring carries on either way.

- The interval point is half the points per game, rounded up. That is 11 for a 21-point game, or 8 for a 15-point game. It is worked out from the format, not set on its own.
- An interval reminder shows when the leading side first reaches the interval point in a game.
- An interval reminder shows between games.
- A change of ends reminder shows between games. The app records whether the players changed ends or skipped it.
- There is no change of ends during a game, in any match length.

**Ending early.** The players can end a match before a side has won it. It then counts as a complete match.

- The leader wins: the side with more games won, or if games are level, the side ahead in the current game.
- If both are level (including 0-0), the players choose the winner.
- Undo reopens the match.
- **Singles:** the server serves from the right service court when their score is even, and from the left when it is odd.
- **Doubles:** each side has one service turn.
    - If the serving side wins the rally, the same player serves again from the other service court.
    - If the receiving side wins the rally, they gain the serve. Players do not change courts. The player in the service court matching their side's score (right if even, left if odd) serves.
    - The receiver is always the player in the service court diagonally opposite the server.
    - Players only change service courts when their side wins a rally on its own serve.
    - At the start of every game, the side serving first chooses which player serves, and the other side chooses which player receives. The app asks for both before each game.

## 7. Non-functional requirements

| ID | Requirement |
| --- | --- |
| NFR-01 | Fully on-device. No server in v1. |
| NFR-02 | Runs a 60+ minute session on a power bank without thermal throttling. |
| NFR-03 | Captures at 60 fps. The shuttle blurs badly at 30. |
| NFR-04 | Decides or prompts a point within about 2 seconds of the rally ending. |
| NFR-05 | Works under typical indoor hall lighting. |
| NFR-06 | Footage never leaves the device except by manual export. |
| NFR-07 | `ScoringKit` has unit tests for every rule in 6.1. |

## 8. Rally state machine

| State | Enters when | Leaves when |
| --- | --- | --- |
| Idle | Previous point awarded | Server takes serve stance |
| Serve | Serve stance detected | Shuttle is struck |
| In rally | Shuttle in play | Shuttle stops or hits the floor |
| Shuttle dead | Shuttle at rest | Winner decided, or Watch prompt answered |
| Point decided | Winner known | Rules engine updates score, back to Idle |

Manual scoring on the Watch can force any state to Point decided.

## 9. Roadmap

Phase 0 gates the automation work. Phase 1 is useful on its own even if automation stalls.

The exit criteria numbers below are proposed starting targets. Revisit them after Phase 0.

### Phase 0: Feasibility spike (no app)

- Record 3 or 4 sessions from the tripod position.
- Hand-label a few hundred rallies: start time, end time, winner.
- Run an open-source TrackNet model on the footage in Python.
- Run a player pose model on the same footage. Choosing a pose library is a new dependency, so ask first.
- Write overlay videos (FR-26) to check shuttle and player tracking by eye.
- Learn Swift basics in parallel.

**Exit:** the shuttle is found in at least 80% of in-rally frames, and rally start and end are found within 1 second on at least 90% of labelled rallies.

**If it fails:** keep Watch-based scoring and test cheaper rally signals, such as hit sounds or player pose, before dropping automation.

### Phase 1: Manual scoring app

- `ScoringKit` with full rules and tests.
- iPhone app, Watch app, and Live Activity.
- Camera view with the live score (FR-29), to frame the court and check the view from the tripod.
- Match history and Watch workout session.
- Every manual point becomes a ground-truth label for later training.

**Exit:** full singles and doubles matches scored from the Watch with the correct server and court on every point. All `ScoringKit` tests pass.

### Phase 2: Record now, analyse later

- The app records video while I score manually.
- Export video and labels to `ml/data/`.
- A Python pipeline detects rallies offline and measures accuracy against manual labels.
- Fine-tune the shuttle model on my own footage and venue.

**Exit:** offline rally detection meets the Phase 0 targets on at least 5 recorded matches.

### Phase 3: Live rally detection

- Core ML model running in the app.
- Court calibration and court mask.
- Live rally start and end detection.
- The Watch asks who won at the end of each rally.
- Optional live tracking overlay on the camera preview (FR-27).

**Exit:** a full match runs live without thermal throttling, and the Watch prompt arrives within 2 seconds of each rally ending.

### Phase 4: Automatic points

- Landing side plus last hitter decides the point.
- Award automatically above a confidence threshold. Prompt below it.

**Exit:** at least 95% of automatic decisions are correct. The prompt rate is tracked per match.

### Phase 5: Extras

Picked from the Could items in section 6, in order of what I actually use.

## 10. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Shuttle is hard to see against bright ceiling lights | Phase 0 tests this before any app work on automation. |
| Neighbouring courts put other shuttles and people in frame | Court mask (FR-14). |
| Heat and battery drain from 60 fps inference | Power bank, reduced inference resolution, profile with Instruments. |
| Close line calls are unreliable | Watch confirm (FR-16). |
| Doubles adds occlusion and harder hitter detection | Expect more Watch prompts in doubles. |
| New to Swift | Start with `ScoringKit`, which is pure logic and easy to test. |

## 11. Tech stack

- **Apps:** Swift and SwiftUI, built in Xcode.
- **Video and ML:** AVFoundation, Vision, Core ML.
- **Data and sync:** WatchConnectivity, SwiftData, HealthKit.
- **Training:** Python, PyTorch, coremltools.
- **Large files:** use Git LFS if Core ML models get large. Footage is never committed.

## 12. Open questions

- [ ] Which iPhone and Apple Watch models will this run on? This affects ML performance.
- [ ] Are the Phase 0 exit targets right, once real footage is in hand?
- [ ] Final app and repository name.

# CourtLog 🎾

Native iOS tennis practice analyzer — court-side camera, ball landing heatmaps, speed estimates, and Apple Watch workout sync.

Inspired by SwingVision, built on open-source CV (TrackNet + homography) with a phased rollout from manual tagging to on-device inference.

## Repository layout

```
CourtLog/
├── docs/                    # Architecture & implementation plans
├── ios/                     # SwiftUI iOS app (Xcode project)
├── cv-service/              # Python CV pipeline (TrackNet, court homography)
└── models/                  # Core ML exports & conversion scripts (git-lfs later)
```

## Quick start (developers)

### iOS (requires macOS + Xcode 15+)

1. Open `ios/CourtLog.xcodeproj`
2. Set your Development Team in Signing & Capabilities
3. Enable HealthKit capability
4. Run on a physical iPhone (camera + HealthKit require device)

### CV service (optional, for cloud post-processing)

```bash
cd cv-service
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## MVP scope (v0.1)

- Record practice session with fixed side-court camera
- Manual 4-point court calibration → homography
- Apple Watch workout sync (duration, HR, calories)
- Post-session upload → cloud CV analysis (ball track, bounces, heatmap)
- Session report + share card

See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for the full roadmap.

## Open-source CV references

| Project | Use in CourtLog |
|---------|-----------------|
| [yastrebksv/TrackNet](https://github.com/yastrebksv/TrackNet) | Ball heatmap tracking → Core ML |
| [ArtLabss/tennis-tracking](https://github.com/artLabss/tennis-tracking) | Full pipeline reference (court, bounce) |
| [bradymcatee/servetracker](https://github.com/bradymcatee/servetracker) | Homography + speed estimation |
| [VKorpelshoek/GridTrackNet](https://github.com/VKorpelshoek/GridTrackNet) | Faster real-time variant (Phase 3) |

## License

TBD — app code MIT; third-party model weights follow upstream licenses.

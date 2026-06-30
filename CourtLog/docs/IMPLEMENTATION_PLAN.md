# CourtLog Implementation Plan

> **For:** Native iOS tennis analyzer (SwingVision-inspired)  
> **Strategy:** Cloud CV first → Core ML on-device → real-time  
> **Open source core:** TrackNet + homography (see ARCHITECTURE.md)

---

## Phase overview

| Phase | Version | Timeline (engineering) | User-facing outcome |
|-------|---------|------------------------|---------------------|
| **0** | — | 3–5 days | Repo, Xcode project, CI, API contract |
| **1** | v0.1 MVP | 2–3 weeks | Record + calibrate + upload + cloud report + HealthKit |
| **2** | v0.2 | 2 weeks | Auto court detect, bounce in/out, share cards |
| **3** | v0.3 | 3–4 weeks | On-device TrackNet Core ML, offline mode |
| **4** | v1.0 | 2+ months | Live overlay, shot labels, subscriptions |

---

## Phase 0 — Foundation (this PR)

### Deliverables

- [x] Architecture & plan docs
- [ ] Xcode project skeleton (`ios/`)
- [ ] CV service skeleton (`cv-service/`)
- [ ] API OpenAPI spec
- [ ] Core ML export script stub

### Tasks

| ID | Task | Owner | Notes |
|----|------|-------|-------|
| P0-1 | Create SwiftUI app target `CourtLog` | iOS | Tab: Home, Record, Sessions |
| P0-2 | Define `Session`, `Calibration`, `AnalysisResult` models | iOS | SwiftData |
| P0-3 | FastAPI `/sessions` CRUD + `/analyze` job endpoint | Backend | Stub returns mock JSON |
| P0-4 | Pin TrackNet dependency in cv-service | Backend | Submodule or pip git URL |
| P0-5 | Document Xcode signing + HealthKit setup | Docs | README |

**Exit criteria:** App builds on device; mock analysis returns heatmap JSON.

---

## Phase 1 — v0.1 MVP ("Record & Review")

### User stories

1. As a player, I mount my phone, calibrate court corners, and record a practice session.
2. As a player, my Apple Watch tracks heart rate during the session.
3. As a player, after I stop recording, the app uploads video and shows a report with landing heatmap and speed stats.

### iOS features

| Feature | Implementation |
|---------|----------------|
| Camera record | `AVCaptureSession`, 1080p30, H.264 to Documents |
| Calibration | 4-tap overlay on first frame; store `3×3` homography |
| Session list | SwiftData + thumbnail |
| Background upload | `URLSession` background configuration |
| HealthKit | Start/stop workout with session; fetch HR stats |
| Report view | `Canvas` heatmap + stat cards |

### CV service features

| Feature | Implementation |
|---------|----------------|
| Video ingest | Multipart upload → S3 |
| Job queue | Redis + worker (or synchronous for MVP) |
| TrackNet infer | `infer_on_video.py` adapted from yastrebksv/TrackNet |
| Homography | User points from iOS JSON |
| Bounce detect | Port heuristic from ArtLabss |
| Output | `analysis.json` + optional `preview.mp4` |

### API contract (v0.1)

```
POST /v1/sessions
  body: { calibration, health metadata }
  → { sessionId, uploadUrl }

PUT  {uploadUrl}  (direct to object storage)

POST /v1/sessions/{id}/analyze
  → { jobId }

GET  /v1/jobs/{jobId}
  → { status, progress, result? }
```

### Testing plan

| Test | Method |
|------|--------|
| Calibration accuracy | Known court dimensions; error < 5% at corners |
| TrackNet on sample | ArtLabss sample video; F1 > 0.7 on bounces |
| End-to-end | 5-min practice clip → report in < 5 min |
| HealthKit | Watch HR appears in report |

### MVP non-goals

- Real-time ball overlay
- Shot type classification (forehand/backhand)
- Multi-camera
- Social / matchmaking

**Exit criteria:** 5 beta users complete full flow on real court.

---

## Phase 2 — v0.2 (Smarter reports)

| Feature | Details |
|---------|---------|
| Auto court calibration | YOLO court keypoints; fallback to manual |
| In/out calls | Bounce y-coord vs court bounds |
| Share card | UIImage export for WeChat / Instagram |
| Session compare | Overlay two heatmaps |
| Watch app | Elapsed time + HR complication |

---

## Phase 3 — v0.3 (On-device CV)

| Feature | Details |
|---------|---------|
| Core ML TrackNet | `export_coreml.py`; 3-frame buffer on ANE |
| Offline mode | No upload; lower-res analysis |
| Live post-shot feedback | 2–3s delay "last shot ~75 km/h" |
| Battery profile | Target < 15% per hour |

Reference: GridTrackNet for speed benchmarks on Apple Silicon.

---

## Phase 4 — v1.0 (Product)

- Live trajectory overlay (Metal + CV)
- Rally segmentation
- Coach mode (multiple players)
- Subscription: free 3 analyses/month, Pro ¥28/month unlimited
- TestFlight → App Store

---

## Open-source integration map

```
cv-service/
├── vendor/
│   └── tracknet/          # git submodule: yastrebksv/TrackNet
├── app/
│   ├── ball_tracker.py    # wraps TrackNet inference
│   ├── homography.py      # from servetracker patterns
│   ├── bounce_detector.py # ArtLabss heuristic
│   └── pipeline.py        # orchestrator
└── scripts/
    ├── export_coreml.py
    └── benchmark.py       # sample videos
```

### Model weights

| Model | Source | Size | License |
|-------|--------|------|---------|
| TrackNet v1 | [Google Drive](https://drive.google.com/file/d/1XEYZ4myUN7QT-NeBYJI0xteLsvs-ZAOl/view) | ~50MB | Research use |
| YOLO court (v0.2) | tennis-analysis repos | ~20MB | AGPL/MIT varies |

**Action:** Download weights in CI secret / local dev only; not committed to git (use LFS or download script).

---

## iOS screen map (v0.1)

```
Home
 ├── Start Session → Calibration → Record → Processing → Report
 └── Past Sessions → Session Detail

Settings
 ├── Cloud upload on/off (future)
 ├── Health permissions
 └── Camera guide
```

### Wireframe priorities

1. **Calibration** — highest UX risk; provide animated guide
2. **Processing** — progress bar + "2–5 min" expectation
3. **Report** — heatmap is the hero metric

---

## Week-by-week sprint (Phase 0 + 1)

### Week 1

| Day | Focus |
|-----|-------|
| 1–2 | Xcode project, navigation, SwiftData models |
| 3 | Camera capture + save file |
| 4 | Calibration UI + homography math (Accelerate) |
| 5 | HealthKit workout integration |

### Week 2

| Day | Focus |
|-----|-------|
| 1–2 | Upload + API client |
| 3–4 | CV service TrackNet integration |
| 5 | Bounce + heatmap JSON |

### Week 3

| Day | Focus |
|-----|-------|
| 1–2 | Report UI (heatmap, speeds) |
| 3 | Error states, retry upload |
| 4–5 | TestFlight build, real-court test |

---

## Success metrics

| Metric | v0.1 target |
|--------|-------------|
| Session completion rate | > 70% |
| Analysis success rate | > 60% of outdoor day sessions |
| Time to report | < 5 min for 30 min video |
| User retention (7-day) | > 40% for beta cohort |

---

## Decisions needed from you

| # | Question | Default if no answer |
|---|----------|----------------------|
| 1 | App name | **CourtLog** |
| 2 | Backend hosting | Railway / Fly.io + R2 storage |
| 3 | Beta language | Chinese UI first |
| 4 | Monetization in v1 | Freemium analysis quota |

---

## Next action after this plan

1. Open `ios/CourtLog.xcodeproj` on your Mac
2. Run on iPhone, verify camera + HealthKit permissions
3. Deploy cv-service stub, run one sample video through TrackNet
4. Record first real session at your club

Reply with your Mac/Xcode availability — we start **P0-1 iOS shell** or **TrackNet worker** next.

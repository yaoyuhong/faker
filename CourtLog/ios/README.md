# CourtLog iOS App

## Create Xcode project (one-time, on Mac)

```bash
cd ios
# Option A: Xcode GUI
# File → New → Project → iOS App
# Product Name: CourtLog, Interface: SwiftUI, Language: Swift
# Save into this ios/ directory, then replace generated Sources with CourtLog/

# Option B: XcodeGen (if installed)
brew install xcodegen
xcodegen generate
open CourtLog.xcodeproj
```

## Capabilities to enable

1. **HealthKit** — Workouts, Heart Rate
2. **Background Modes** — Background fetch (upload)
3. **Camera** — `NSCameraUsageDescription` in Info.plist
4. **Photo Library** (optional) — import existing videos

## Info.plist keys

```xml
<key>NSCameraUsageDescription</key>
<string>CourtLog records your practice session to analyze ball placement.</string>
<key>NSHealthShareUsageDescription</key>
<string>Sync heart rate and calories from Apple Watch during practice.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Save tennis workouts to Apple Health.</string>
```

## Minimum deployment

- iOS 17.0+
- Xcode 15+
- Physical device required for Camera + HealthKit

## Module structure

```
CourtLog/
├── App/CourtLogApp.swift
├── Models/Session.swift
├── Services/CameraService.swift
├── Services/HealthKitService.swift
├── Services/HomographyService.swift
├── Services/AnalysisAPIClient.swift
├── Views/HomeView.swift
├── Views/CalibrationView.swift
├── Views/RecordView.swift
├── Views/ReportView.swift
└── Views/SessionListView.swift
```

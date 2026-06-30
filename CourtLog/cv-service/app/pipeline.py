"""End-to-end analysis orchestrator."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from app.ball_tracker import BallObservation, TrackNetBallTracker
from app.bounce_detector import detect_bounces
from app.homography import compute_homography, image_to_court


def run_pipeline(
    video_path: Path,
    image_points: list[tuple[float, float]],
    court_points: list[tuple[float, float]],
    weights_path: Path | None = None,
    heatmap_grid: int = 10,
) -> dict:
    tracker = TrackNetBallTracker(weights_path=weights_path)
    observations: list[BallObservation]

    if tracker.is_ready:
        observations = tracker.track_video(video_path)
    else:
        observations = _synthetic_observations(video_path)

    h = compute_homography(
        np.array(image_points, dtype=np.float64),
        np.array(court_points, dtype=np.float64),
    )

    court_track: list[tuple[float, float, float]] = []
    ball_positions = []
    for obs in observations:
        if not obs.visible:
            continue
        x_m, y_m = image_to_court(h, obs.x_pixel, obs.y_pixel)
        court_track.append((obs.timestamp_sec, x_m, y_m))
        ball_positions.append({"t": obs.timestamp_sec, "x": x_m, "y": y_m})

    bounces_raw = detect_bounces(court_track)
    bounces = [
        {
            "t": b.timestamp_sec,
            "x": b.x_m,
            "y": b.y_m,
            "in": b.in_court,
            "speedKmh": round(b.speed_kmh, 1),
        }
        for b in bounces_raw
    ]

    speeds = [b["speedKmh"] for b in bounces]
    heatmap = _build_heatmap(
        [(p["x"], p["y"]) for p in ball_positions],
        grid=heatmap_grid,
        court_length=23.77,
        court_width=8.23,
    )

    return {
        "ballPositions": ball_positions,
        "bounces": bounces,
        "heatmap": heatmap,
        "maxSpeedKmh": round(max(speeds), 1) if speeds else 0.0,
        "avgSpeedKmh": round(sum(speeds) / len(speeds), 1) if speeds else 0.0,
        "previewUrl": None,
        "meta": {
            "tracknet": tracker.is_ready,
            "observationCount": len(ball_positions),
        },
    }


def _synthetic_observations(video_path: Path) -> list[BallObservation]:
    """Demo path when TrackNet weights are missing — parabolic arc in frame."""
    try:
        import cv2
    except ImportError:
        return []

    cap = cv2.VideoCapture(str(video_path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    cap.release()

    if frame_count <= 0:
        frame_count = 90

    observations: list[BallObservation] = []
    for i in range(frame_count):
        t = i / fps
        x = 200 + (i / max(frame_count, 1)) * 400
        y = 100 + abs(np.sin(i / 15)) * 120
        observations.append(
            BallObservation(
                frame_index=i,
                timestamp_sec=t,
                x_pixel=x,
                y_pixel=y,
                visible=True,
            )
        )
    return observations


def _build_heatmap(
    points: list[tuple[float, float]],
    grid: int,
    court_width: float,
    court_length: float,
) -> dict:
    rows = int(grid * (court_length / court_width))
    counts = [[0] * grid for _ in range(rows)]
    for x, y in points:
        if not (0 <= x <= court_width and 0 <= y <= court_length):
            continue
        c = min(int(x / court_width * grid), grid - 1)
        r = min(int(y / court_length * rows), rows - 1)
        counts[r][c] += 1
    return {"grid": grid, "counts": counts}

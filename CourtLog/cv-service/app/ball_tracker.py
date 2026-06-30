"""Ball tracking via TrackNet heatmap model.

Integrates with yastrebksv/TrackNet when weights are present at models/tracknet.pth.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import numpy as np

try:
    import cv2
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore


@dataclass
class BallObservation:
    frame_index: int
    timestamp_sec: float
    x_pixel: float
    y_pixel: float
    visible: bool


class TrackNetBallTracker:
    """Wraps TrackNet inference. Falls back to empty track if model missing."""

    def __init__(self, weights_path: Path | None = None, fps: float = 30.0) -> None:
        self.weights_path = weights_path
        self.fps = fps
        self._model = None
        if weights_path and weights_path.exists():
            self._load_model(weights_path)

    def _load_model(self, path: Path) -> None:
        # TODO: load PyTorch TrackNet from vendor/tracknet
        _ = path

    def track_video(self, video_path: Path) -> list[BallObservation]:
        if cv2 is None:
            raise RuntimeError("opencv-python-headless is required")

        if self._model is None:
            return []

        cap = cv2.VideoCapture(str(video_path))
        observations: list[BallObservation] = []
        frame_idx = 0
        buffer: list[np.ndarray] = []

        while True:
            ok, frame = cap.read()
            if not ok:
                break
            resized = cv2.resize(frame, (640, 360))
            buffer.append(resized)
            if len(buffer) >= 3:
                x, y, visible = self._infer_triplet(buffer[-3:])
                observations.append(
                    BallObservation(
                        frame_index=frame_idx,
                        timestamp_sec=frame_idx / self.fps,
                        x_pixel=x,
                        y_pixel=y,
                        visible=visible,
                    )
                )
            frame_idx += 1

        cap.release()
        return observations

    def _infer_triplet(self, frames: list[np.ndarray]) -> tuple[float, float, bool]:
        # Placeholder until TrackNet weights wired
        _ = frames
        return 0.0, 0.0, False

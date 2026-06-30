"""Ball tracking via TrackNet heatmap model."""

from __future__ import annotations

from dataclasses import dataclass
from itertools import groupby
from pathlib import Path

import numpy as np
from scipy.spatial import distance

from vendor.tracknet.model import BallTrackerNet
from vendor.tracknet.postprocess import postprocess

try:
    import cv2
    import torch
except ImportError:  # pragma: no cover
    cv2 = None  # type: ignore
    torch = None  # type: ignore

WIDTH = 640
HEIGHT = 360


@dataclass
class BallObservation:
    frame_index: int
    timestamp_sec: float
    x_pixel: float
    y_pixel: float
    visible: bool


class TrackNetBallTracker:
    """TrackNet inference with outlier removal and gap interpolation."""

    def __init__(
        self,
        weights_path: Path | None = None,
        device: str | None = None,
    ) -> None:
        self.weights_path = weights_path
        self.device = device or ("cuda" if torch and torch.cuda.is_available() else "cpu")
        self._model: BallTrackerNet | None = None
        self.fps = 30.0

        if weights_path and weights_path.exists() and torch is not None:
            self._load_model(weights_path)

    @property
    def is_ready(self) -> bool:
        return self._model is not None

    def _load_model(self, path: Path) -> None:
        assert torch is not None
        model = BallTrackerNet()
        try:
            state = torch.load(path, map_location=self.device, weights_only=True)
        except TypeError:
            state = torch.load(path, map_location=self.device)
        model.load_state_dict(state)
        model = model.to(self.device)
        model.eval()
        self._model = model

    def track_video(self, video_path: Path) -> list[BallObservation]:
        if cv2 is None or torch is None:
            raise RuntimeError("opencv and torch are required")
        if self._model is None:
            raise RuntimeError(
                f"TrackNet weights not found. Place tracknet.pth in models/ "
                f"(expected: {self.weights_path})"
            )

        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            raise RuntimeError(f"cannot open video: {video_path}")

        self.fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        frames: list[np.ndarray] = []
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            frames.append(frame)
        cap.release()

        if len(frames) < 3:
            return []

        ball_track, dists = self._infer_frames(frames)
        ball_track = self._remove_outliers(ball_track, dists)

        for start, end in self._split_track(ball_track):
            segment = self._interpolate(ball_track[start:end])
            ball_track[start:end] = segment

        observations: list[BallObservation] = []
        for idx, (x, y) in enumerate(ball_track):
            visible = x is not None and y is not None
            observations.append(
                BallObservation(
                    frame_index=idx,
                    timestamp_sec=idx / self.fps,
                    x_pixel=float(x or 0),
                    y_pixel=float(y or 0),
                    visible=visible,
                )
            )
        return observations

    def _infer_frames(self, frames: list[np.ndarray]) -> tuple[list[tuple], list[float]]:
        assert self._model is not None and torch is not None
        ball_track: list[tuple] = [(None, None), (None, None)]
        dists: list[float] = [-1.0, -1.0]

        with torch.no_grad():
            for num in range(2, len(frames)):
                tensors = []
                for offset in (0, -1, -2):
                    img = cv2.resize(frames[num + offset], (WIDTH, HEIGHT))
                    tensors.append(img)
                imgs = np.concatenate(tensors, axis=2).astype(np.float32) / 255.0
                imgs = np.rollaxis(imgs, 2, 0)
                inp = np.expand_dims(imgs, axis=0)
                out = self._model(torch.from_numpy(inp).float().to(self.device))
                output = out.argmax(dim=1).detach().cpu().numpy()
                x_pred, y_pred = postprocess(output[0])
                ball_track.append((x_pred, y_pred))

                if ball_track[-1][0] and ball_track[-2][0]:
                    dist = distance.euclidean(ball_track[-1], ball_track[-2])
                else:
                    dist = -1.0
                dists.append(dist)

        return ball_track, dists

    @staticmethod
    def _remove_outliers(ball_track: list[tuple], dists: list[float], max_dist: float = 100) -> list[tuple]:
        outliers = list(np.where(np.array(dists) > max_dist)[0])
        for i in outliers.copy():
            if (dists[i + 1] > max_dist) or (dists[i + 1] == -1):
                ball_track[i] = (None, None)
                outliers.remove(i)
            elif dists[i - 1] == -1:
                ball_track[i - 1] = (None, None)
        return ball_track

    @staticmethod
    def _split_track(
        ball_track: list[tuple],
        max_gap: int = 4,
        max_dist_gap: float = 80,
        min_track: int = 5,
    ) -> list[list[int]]:
        list_det = [0 if x[0] else 1 for x in ball_track]
        groups = [(k, sum(1 for _ in g)) for k, g in groupby(list_det)]

        cursor = 0
        min_value = 0
        result: list[list[int]] = []
        for i, (k, length) in enumerate(groups):
            if (k == 1) and (i > 0) and (i < len(groups) - 1):
                dist = distance.euclidean(ball_track[cursor - 1], ball_track[cursor + length])
                if (length >= max_gap) or (dist / max(length, 1) > max_dist_gap):
                    if cursor - min_value > min_track:
                        result.append([min_value, cursor])
                    min_value = cursor + length - 1
            cursor += length
        if len(list_det) - min_value > min_track:
            result.append([min_value, len(list_det)])
        return result

    @staticmethod
    def _interpolate(coords: list[tuple]) -> list[tuple]:
        x = np.array([p[0] if p[0] is not None else np.nan for p in coords])
        y = np.array([p[1] if p[1] is not None else np.nan for p in coords])

        def fill_axis(values: np.ndarray) -> np.ndarray:
            nans = np.isnan(values)
            if nans.all():
                return values
            if not nans.any():
                return values
            idx = np.arange(len(values))
            values[nans] = np.interp(idx[nans], idx[~nans], values[~nans])
            return values

        x = fill_axis(x)
        y = fill_axis(y)
        return list(zip(x, y))

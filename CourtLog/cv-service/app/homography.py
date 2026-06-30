"""Homography and court coordinate mapping."""

from __future__ import annotations

import numpy as np


def compute_homography(
    image_points: np.ndarray,
    court_points_meters: np.ndarray,
) -> np.ndarray:
    """DLT homography from 4+ correspondences. Points shape (N, 2), N >= 4."""
    if image_points.shape[0] < 4:
        raise ValueError("need at least 4 point pairs")

    a_rows: list[list[float]] = []
    for (u, v), (x, y) in zip(image_points, court_points_meters):
        a_rows.append([-u, -v, -1, 0, 0, 0, u * x, v * x, x])
        a_rows.append([0, 0, 0, -u, -v, -1, u * y, v * y, y])

    a = np.array(a_rows, dtype=np.float64)
    _, _, vt = np.linalg.svd(a)
    h = vt[-1].reshape(3, 3)
    return h / h[2, 2]


def image_to_court(h: np.ndarray, x_pixel: float, y_pixel: float) -> tuple[float, float]:
    p = np.array([x_pixel, y_pixel, 1.0])
    mapped = h @ p
    return float(mapped[0] / mapped[2]), float(mapped[1] / mapped[2])


def estimate_speed_kmh(
    positions: list[tuple[float, float, float]],
) -> list[float]:
    """positions: (t_sec, x_m, y_m) → speed km/h between consecutive visible points."""
    speeds: list[float] = []
    for i in range(1, len(positions)):
        t0, x0, y0 = positions[i - 1]
        t1, x1, y1 = positions[i]
        dt = t1 - t0
        if dt <= 0:
            speeds.append(0.0)
            continue
        dist = np.hypot(x1 - x0, y1 - y0)
        speeds.append(dist / dt * 3.6)
    return speeds

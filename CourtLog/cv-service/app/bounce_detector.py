"""Bounce detection heuristics (ported from ArtLabss/tennis-tracking concepts)."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class BounceEvent:
    timestamp_sec: float
    x_m: float
    y_m: float
    speed_kmh: float
    in_court: bool


def detect_bounces(
    court_positions: list[tuple[float, float, float]],
    court_width: float = 8.23,
    court_length: float = 23.77,
    vy_threshold: float = 0.5,
) -> list[BounceEvent]:
    """Detect bounces when vertical velocity (y) changes sign sharply.

    court_positions: list of (t, x_m, y_m)
    """
    events: list[BounceEvent] = []
    if len(court_positions) < 3:
        return events

    for i in range(1, len(court_positions) - 1):
        t0, x0, y0 = court_positions[i - 1]
        t1, x1, y1 = court_positions[i]
        t2, x2, y2 = court_positions[i + 1]
        vy_before = (y1 - y0) / max(t1 - t0, 1e-6)
        vy_after = (y2 - y1) / max(t2 - t1, 1e-6)
        if vy_before > vy_threshold and vy_after < -vy_threshold:
            dt = t2 - t0
            speed = ((x2 - x0) ** 2 + (y2 - y0) ** 2) ** 0.5 / max(dt, 1e-6) * 3.6
            in_court = 0 <= x1 <= court_width and 0 <= y1 <= court_length
            events.append(
                BounceEvent(
                    timestamp_sec=t1,
                    x_m=x1,
                    y_m=y1,
                    speed_kmh=speed,
                    in_court=in_court,
                )
            )
    return events
